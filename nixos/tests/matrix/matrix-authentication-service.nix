{
  pkgs,
  lib,
  ...
}:
{
  name = "matrix-authentication-service";
  meta.maintainers = [ lib.maintainers.teutat3s ];

  nodes.machine =
    { ... }:
    {
      services.matrix-authentication-service = {
        enable = true;
        createDatabase = true;
        settings = {
          http.public_base = "http://localhost:8080/";
          matrix = {
            homeserver = "localhost";
            endpoint = "http://localhost:8008/";
            secret_file = "/var/lib/matrix-authentication-service/matrix_secret";
          };
          secrets = {
            encryption_file = "/var/lib/matrix-authentication-service/encryption";
            keys = [
              {
                kid = "rsa-4096";
                key_file = "/var/lib/matrix-authentication-service/key_rsa_4096";
              }
            ];
          };
        };
      };

      systemd.services.matrix-authentication-service.preStart = ''
        if [ ! -f /var/lib/matrix-authentication-service/matrix_secret ]; then
          echo -n 'dummy-matrix-secret' > /var/lib/matrix-authentication-service/matrix_secret
        fi
        if [ ! -f /var/lib/matrix-authentication-service/encryption ]; then
          echo -n '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef' > /var/lib/matrix-authentication-service/encryption
        fi
        if [ ! -f /var/lib/matrix-authentication-service/key_rsa_4096 ]; then
          ${pkgs.openssl}/bin/openssl genrsa -out /var/lib/matrix-authentication-service/key_rsa_4096 4096
        fi
      '';
    };

  testScript = ''
    machine.wait_for_unit("postgresql.service")
    machine.wait_for_unit("matrix-authentication-service.service")
    machine.wait_for_open_port(8081)
    machine.succeed("curl --fail http://localhost:8081/health")
  '';
}
