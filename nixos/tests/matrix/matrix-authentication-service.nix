{
  pkgs,
  lib,
  ...
}:
let
  synapseClientSecret = "test_synapse_client_secret";
  matrixSecret = "test_matrix_shared_secret_0123456789abcdef";
  testUser = "alice";
  testPassword = "alicepassword123";
in
{
  name = "matrix-authentication-service";
  meta.maintainers = with lib.maintainers; [ teutat3s ];

  nodes.machine =
    { config, pkgs, ... }:
    {
      services.postgresql = {
        enable = true;
        ensureDatabases = [ "matrix-synapse" "matrix-authentication-service" ];
        ensureUsers = [
          {
            name = "matrix-synapse";
            ensureDBOwnership = true;
          }
          {
            name = "matrix-authentication-service";
            ensureDBOwnership = true;
          }
        ];
      };

      services.matrix-synapse = {
        enable = true;
        settings = {
          server_name = "localhost";
          public_baseurl = "http://localhost:8008/";
          database = {
            name = "psycopg2";
            args.user = "matrix-synapse";
            args.database = "matrix-synapse";
            args.host = "/run/postgresql";
          };
          listeners = [
            {
              port = 8008;
              bind_addresses = [ "127.0.0.1" ];
              type = "http";
              tls = false;
              x_forwarded = true;
              resources = [
                {
                  names = [ "client" "federation" ];
                  compress = false;
                }
              ];
            }
          ];
          experimental_features.msc3861 = {
            enabled = true;
            issuer = "http://localhost:8080/";
            client_id = "synapse";
            client_auth_method = "client_secret_basic";
            client_secret = synapseClientSecret;
            admin_token = matrixSecret;
          };
        };
      };

      services.matrix-authentication-service = {
        enable = true;
        createDatabase = false;
        settings = {
          http.public_base = "http://localhost:8080/";

          matrix = {
            homeserver = "localhost";
            endpoint = "http://localhost:8008/";
            secret_file = "/var/lib/matrix-authentication-service/matrix_secret";
          };

          database.uri = "postgresql:///matrix-authentication-service?host=/run/postgresql";

          secrets = {
            encryption_file = "/var/lib/matrix-authentication-service/encryption";
            keys = [
              {
                kid = "rsa-4096";
                key_file = "/var/lib/matrix-authentication-service/key_rsa_4096";
              }
            ];
          };

          clients = [
            {
              client_id = "synapse";
              client_secret = synapseClientSecret;
            }
          ];
        };
      };

      systemd.services.matrix-authentication-service.preStart = ''
        mkdir -p /var/lib/matrix-authentication-service

        echo -n '${matrixSecret}' > /var/lib/matrix-authentication-service/matrix_secret
        echo -n '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef' > /var/lib/matrix-authentication-service/encryption
          ${pkgs.openssl}/bin/openssl genrsa -out /var/lib/matrix-authentication-service/key_rsa_4096 4096
        chown -R matrix-authentication-service:matrix-authentication-service /var/lib/matrix-authentication-service
>>>>>>> Stashed changes
      '';
    };

  testScript = ''
    machine.wait_for_unit("matrix-authentication-service.service")

    machine.wait_for_open_port(8008) # Synapse
    machine.wait_for_open_port(8080) # MAS Web listener
    machine.wait_for_open_port(8081) # MAS Internal listener

    with subtest("Ensure MAS health and discovery endpoints are responsive"):
        machine.succeed("curl --fail http://localhost:8081/health")
        machine.succeed("curl --fail http://localhost:8080/.well-known/openid-configuration")

    with subtest("Create a test user via MAS CLI"):
        # We run the CLI command as the MAS user to ensure permissions line up with the database
        machine.succeed(
            "su -s /bin/sh matrix-authentication-service -c "
            "'matrix-authentication-service manage user add ${testUser} ${testPassword}'"
        )

    with subtest("Authenticate test user via MAS Compat API"):
        # MAS implements the Matrix Client-Server API for /login to provide backwards compatibility.
        # If this succeeds and returns an access_token, MAS is successfully authenticating users.
        response = machine.succeed(
            "curl --fail -s -X POST http://localhost:8080/_matrix/client/r0/login "
            "-H 'Content-Type: application/json' "
            "-d '{\"type\":\"m.login.password\",\"identifier\":{\"type\":\"m.id.user\",\"user\":\"${testUser}\"},\"password\":\"${testPassword}\"}'"
        )

        # Verify the response contains an access token
        assert "access_token" in response, f"Authentication failed, no access_token in response: {response}"
  '';
}
