{
  lib,
  buildGoModule,
  fetchFromGitHub,
  fetchpatch,
  installShellFiles,
  makeWrapper,
  iproute2,
  iptables,
  procps,
  tailscale,
  versionCheckHook,
  nix-update-script,
  nixosTests,
  stdenv,
}:

buildGoModule (finalAttrs: {
  pname = "hydrascale";
  version = "1.8.1";

  __structuredAttrs = true;
  strictDeps = true;

  src = fetchFromGitHub {
    owner = "Crank-Git";
    repo = "Hydrascale";
    tag = "v${finalAttrs.version}";
    hash = "sha256-0/o7eq653KwdPWsvy02dFqArBweVx+sfyddpmrtKXVM=";
  };

  # seed the namespace overlay resolv.conf and write bare hostnames to /etc/hosts, so
  # MagicDNS activates and unprefixed names resolve without systemd-resolved
  # (Crank-Git/Hydrascale#480, fixed by #481); drop when a release includes it
  postPatch = ''
    substituteInPlace go.mod --replace-fail "go 1.26.11" "go 1.26.10"
  '';

  patches = [
    # PR #481: Seed overlay resolv.conf from namespace file (Fixes #480)
    (fetchpatch {
      name = "hydrascale-seed-resolv-conf.patch";
      url = "https://github.com/hatch01/Hydrascale/commit/f9350ebef175c59c7a13e5e6a4176c31355ab018.patch";
      excludes = [ "docs/*" ];
      hash = "sha256-hinQDDCqk/UJlhqEYTFdNf5gXndiIgVMZ3iZfFNZ2Ck=";
    })
    # Write bare hostnames and aliases to /etc/hosts
    (fetchpatch {
      name = "hydrascale-hosts-bare-names.patch";
      url = "https://github.com/hatch01/Hydrascale/commit/74881a7087d654b6fe71960504780ee58adab6a1.patch";
      hash = "sha256-dz5i/HJ6ZNlrmR/ha6adUunlEgGbt6qJh/nkU9lYWpw=";
    })
  ];

  vendorHash = "sha256-eQHU0tkhWIAqVMp9mAsD8Se53QOGdUA9rbk4QdpvpnQ=";

  env.CGO_ENABLED = "0";

  subPackages = [ "cmd/hydrascale" ];

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${finalAttrs.version}"
  ];

  nativeBuildInputs = [
    installShellFiles
    makeWrapper
  ];

  # the daemon shells out to ip, ss, iptables, sysctl, tailscale and tailscaled; suffix so
  # the system's own tailscale wins when there is one
  postInstall = ''
    wrapProgram $out/bin/hydrascale \
      --suffix PATH : ${
        lib.makeBinPath [
          iproute2
          iptables
          procps
          tailscale
        ]
      }
  ''
  + lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
    installShellCompletion --cmd hydrascale \
      --bash <($out/bin/hydrascale completion bash) \
      --fish <($out/bin/hydrascale completion fish) \
      --zsh <($out/bin/hydrascale completion zsh)
  '';

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;

  passthru = {
    tests = { inherit (nixosTests) hydrascale; };
    updateScript = nix-update-script { };
  };

  meta = {
    description = "Run multiple Tailscale tailnets simultaneously on one Linux host";
    longDescription = ''
      Hydrascale runs one tailscaled per tailnet, each inside its own network
      namespace, and reconciles the host toward a declarative YAML config. It
      handles host routes, per-tailnet MagicDNS, local reachability rules and
      Headscale control servers.
    '';
    homepage = "https://github.com/Crank-Git/Hydrascale";
    changelog = "https://github.com/Crank-Git/Hydrascale/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ sophronesis ];
    platforms = lib.platforms.linux;
    mainProgram = "hydrascale";
  };
})
