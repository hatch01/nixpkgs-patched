{
  base58,
  buildPythonPackage,
  cashaddress,
  fetchFromGitHub,
  lib,
  pbkdf2,
  pyperclip,
  pythonRelaxDepsHook,
  requests,
  setuptools,
}:

buildPythonPackage rec {
  pname = "pycryptotools";
  version = "0.4.1";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "Toporin";
    repo = "pybitcointools";
    rev = "v${version}";
    hash = "sha256-6INyD24OVcIYDiWK9/bHAIh9crpeJBDLeUqQ9+P24HM=";
  };

  build-system = [ setuptools ];

  nativeBuildInputs = [ pythonRelaxDepsHook ];
  pythonRelaxDeps = [ "requests" ]; # pycryptotools request requests~=2.32.3 which is older than the one in nixpkgs

  dependencies = [
    pbkdf2
    requests
    cashaddress
    pyperclip
    base58
  ];

  pythonImportsCheck = [ "pycryptotools" ];

  meta = {
    description = "Python library for Crypto coins signatures and transactions";
    homepage = "https://pypi.org/project/pycryptotools/";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ eymeric ];
  };
}
