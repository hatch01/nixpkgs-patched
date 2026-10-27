{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  certifi,
  cryptography,
  pyaes,
  pycryptodomex,
  pyopenssl,
  pyscard,
  pytestCheckHook,
  setuptools,
}:

buildPythonPackage rec {
  pname = "pysatochip";
  version = "0.18.7";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "Toporin";
    repo = "pysatochip";
    tag = "v${version}";
    hash = "sha256-J4VGdeC+IowqWnCP8JFWGU8yPEaYCzfVn6F025/mwKY=";
  };

  build-system = [
    setuptools
  ];

  dependencies = [
    certifi
    cryptography
    pyaes
    pycryptodomex
    pyopenssl
    pyscard
  ];

  nativeCheckInputs = [
    pytestCheckHook
  ];

  enabledTestPaths = [
    "tests"
  ];

  disabledTestPaths = [
    # Requires extra dependencies (nostr, click) for CLI
    "tests/test_cli_commands.py"
    "tests/test_cli_entry.py"
  ];

  pythonImportsCheck = [ "pysatochip" ];

  meta = {
    description = "Simple python library to communicate with a Satochip hardware wallet";
    homepage = "https://github.com/Toporin/pysatochip";
    license = lib.licenses.lgpl3Only;
    maintainers = with lib.maintainers; [ oxalica ];
  };
}
