// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.13;

import {ERC721, ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";
import {Create2} from "create2/Create2.sol";
import {Decimal} from "codec/Decimal.sol";
import {Hexadecimal} from "codec/Hexadecimal.sol";
import {SVG} from "svg/SVG.sol";
import {ERC721MetadataJSON} from "erc721metadata-json/ERC721MetadataJSON.sol";

error ProgramExists();

library Id {
  function id(address a) internal pure returns (uint) {
    return uint(uint160(a));
  }
  function addr(uint i) internal pure returns (address) {
    return address(uint160(i));
  }
}

contract Programs is ERC721 {
  using Id for uint;
  using Id for address;
  using Hexadecimal for address;
  using Decimal for uint;

  uint constant public salt = 0;
  address public admin;

  constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) {
    _ownerOf[address(this).id()] = msg.sender;
    admin = msg.sender;
  }

  modifier onlyAdmin() {
    require(msg.sender == admin);
    _;
  }

  function setAdmin(address _admin) external onlyAdmin {
    admin = _admin;
  }

  function tokenURI(address program) public view returns (string memory) {
    require(ownerOf(program.id()) != address(0), "TOKEN_DOESNT_EXIST");

    bytes memory addr = program.hexadecimal();
    bytes memory size = program.code.length.decimal();
    bytes[] memory keys = new bytes[](1);
    bytes[] memory values = new bytes[](1);
    keys[0] = "size";
    values[0] = size;

    return string(
      ERC721MetadataJSON.uriBase64(
        ERC721MetadataJSON.json(
          bytes.concat("Program ", addr),
          bytes.concat("Program at ", addr),
          SVG.uriBase64(
            SVG.svg(
              bytes.concat(
                SVG.text("Program", 20, 20),
                SVG.text(bytes.concat("Address: ", addr), 20, 40),
                SVG.text(bytes.concat("Size: ", size), 20, 60)
              ),
              480,
              100
            )
          ),
          keys,
          values
        )
      )
    );
  }

  function tokenURI(uint id) public view override returns (string memory) {
    return tokenURI(id.addr());
  }

  function write (bytes memory creationCode) external returns (address program) {
    program = Create2.create2(salt, creationCode);
    if (program == address(0)) {
      revert ProgramExists();
    }

    _mint(msg.sender, program.id());
  }
}
