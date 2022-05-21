// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.13;
import {ERC721} from "solmate/tokens/ERC721.sol";
import {Authority} from "solmate/auth/Auth.sol";
import {MultiRolesAuthority} from "solmate/auth/authorities/MultiRolesAuthority.sol";
import {Id} from "./Programs.sol";
import {Hexadecimal} from "codec/Hexadecimal.sol";
import {SVG} from "svg/SVG.sol";
import {ERC721MetadataJSON} from "erc721metadata-json/ERC721MetadataJSON.sol";

abstract contract Challenge {
  function challenge(address program) external virtual returns (bool);
}


contract Challenges is ERC721, MultiRolesAuthority {
  using Id for address;
  using Id for uint;
  using Hexadecimal for address;

  event ReviewChallenge(uint indexed id, bool accepted, bytes message);
  mapping (uint => bool) public accepted;
  mapping (uint => bytes) public descriptionOf;

  constructor (string memory _name, string memory _symbol) ERC721(_name, _symbol) MultiRolesAuthority(msg.sender, Authority(address(0))) {
    setPublicCapability(Challenges.reviewChallenge.selector, false);
    setRoleCapability(1, Challenges.reviewChallenge.selector, true);
  }

  function tokenURI(uint id) public view override returns (string memory) {
    // Reverts on nonexistent token
    ownerOf(id);

    bytes memory addr = id.addr().hexadecimal();
    bytes memory desc = descriptionOf[id];
    bytes memory status = bytes(accepted[id] ? "Accepted" : "Pending");

    bytes[] memory keys = new bytes[](1);
    bytes[] memory values = new bytes[](1);
    keys[0] = "Status";
    values[0] = bytes.concat("\"", status, "\"");

    return string(
      ERC721MetadataJSON.uriBase64(
        ERC721MetadataJSON.json(
          bytes.concat("Challenge ", addr),
          desc,
          SVG.uriBase64(
            SVG.svg(
              bytes.concat(
                SVG.text("Challenge", 20, 20),
                SVG.text(bytes.concat("Address: ", addr), 20, 40),
                SVG.text(bytes.concat("Description: ", desc), 20, 60),
                SVG.text(bytes.concat("Status: ", status), 20, 80)
              ),
              480,
              120
            )
          ),
          keys,
          values
        )
      )
    );
  }

  function requestChallenge(address challenge, bytes calldata description) external requiresAuth {
    descriptionOf[challenge.id()] = description;
    _safeMint(msg.sender, challenge.id());
  }

  function reviewChallenge(uint id, bool _accepted, bytes calldata message) external requiresAuth {
    if (_accepted) {
      accepted[id] = true;
    } else {
      _burn(id);
      delete descriptionOf[id];
    }
    emit ReviewChallenge(id, _accepted, message);
  }
}
