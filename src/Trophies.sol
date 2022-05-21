// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.13;
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC721, ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";
import {Decimal} from "codec/Decimal.sol";
import {Hexadecimal} from "codec/Hexadecimal.sol";
import {SVG} from "svg/SVG.sol";
import {ERC721MetadataJSON} from "erc721metadata-json/ERC721MetadataJSON.sol";
import {Id, Programs} from "./Programs.sol";
import {Challenge, Challenges} from "./Challenge.sol";

struct Trophy {
  uint gasUsed;
  address challenge;
  address program;
}

struct RecordStruct {
  uint size;
  uint gas;
}

contract Trophies is ERC721 {
  using Id for address;
  using Hexadecimal for address;
  using Decimal for uint;

  event Funded(address indexed challenge, uint value);
  event Payed(address indexed winner, address indexed challenge, uint value);
  event Record(address indexed challenge, address indexed program, uint size, uint gas);

  uint public totalSupply;
  mapping (uint => Trophy) trophies;
  mapping (address => uint) public funds;
  mapping (address => RecordStruct) public records;

  Challenges challenges;
  Programs programs;

  constructor (string memory _name, string memory _symbol, address _challenges, address _programs) ERC721(_name, _symbol) {
    challenges = Challenges(_challenges);
    programs = Programs(_programs);
  }

  function _mint(address to) internal returns (uint id) {
    id = totalSupply++;
    _mint(to, id);
  }

  function _safeMint(address to) internal returns (uint id) {
    id = _mint(to);
    require(
      to.code.length == 0 ||
        ERC721TokenReceiver(to).onERC721Received(msg.sender, address(0), id, "") ==
        ERC721TokenReceiver.onERC721Received.selector,
      "UNSAFE_RECIPIENT"
    );
  }

  function tokenURI(uint id) public view override returns (string memory) {
    bytes[] memory keys = new bytes[](6);
    bytes[] memory values = new bytes[](6);
    bytes memory lines;

    {
      Trophy memory trophy = trophies[id];

      {
        bytes memory challenge = trophy.challenge.hexadecimal();
        keys[0] = "Challenge";
        values[0] = bytes.concat("\"", challenge, "\"");
        lines = SVG.text(bytes.concat("Challenge: ", challenge), 20, 40);
      }
      {
        bytes memory program = trophy.program.hexadecimal();
        keys[1] = "Program";
        values[1] = bytes.concat("\"", program, "\"");
        lines = bytes.concat(lines, SVG.text(bytes.concat("Program:   ", program), 20, 60));
      }
      {
        uint sizeValue = trophy.program.code.length;
        bytes memory size = sizeValue.decimal();
        bool sizeRecord = sizeValue == records[trophy.challenge].size;

        keys[4] = "Size";
        values[4] = size;
        keys[5] = "Size Record";
        values[5] = bytes(sizeRecord ? "true" : "false");
        lines = bytes.concat(lines, SVG.text(bytes.concat("Size: ", size, bytes(sizeRecord ? unicode" ⭐" : "")), 20, 80));
      }
      {
        bytes memory gas = trophy.gasUsed.decimal();
        bool gasRecord = trophy.gasUsed == records[trophy.challenge].gas;
        keys[2] = "Gas";
        values[2] = gas;
        keys[3] = "Gas Record";
        values[3] = bytes(gasRecord ? "true" : "false");
        lines = bytes.concat(lines, SVG.text(bytes.concat("Gas: ", gas, bytes(gasRecord ? unicode" ⭐" : "")), 20, 100));
      }
    }

    bytes memory title = bytes.concat(bytes(name), " #", id.decimal());

    return string(
      ERC721MetadataJSON.uriBase64(
        ERC721MetadataJSON.json(
          title,
          title,
          SVG.uriBase64(
            SVG.svg(
              bytes.concat(
                SVG.text(title, 20, 20),
                lines
              ),
              480,
              140
            )
          ),
          keys,
          values
        )
      )
    );
  }

  function isRecord(Trophy memory trophy) public view returns (bool, bool) {
    return (
      trophy.program.code.length == records[trophy.challenge].size,
      trophy.gasUsed == records[trophy.challenge].gas
    );
  }

  function isRecord(uint id) public view returns (bool, bool) {
    return isRecord(trophies[id]);
  }

  function fund(address challenge) external payable {
    require(challenges.accepted(challenge.id()), "CHALLENGE_NOT_ACCEPTED");
    require(msg.value > 0, "NO_VALUE");
    funds[challenge] += msg.value;
    emit Funded(challenge, msg.value);
  }

  function submit(address challenge, address program) external returns (uint id) {
    require(challenges.accepted(challenge.id()), "CHALLENGE_NOT_ACCEPTED");
    require(programs.ownerOf(program.id()) == msg.sender, "PROGRAM_NOT_OWNED");
    uint gas = gasleft();
    bool result = Challenge(challenge).challenge(program);
    gas -= gasleft();
    require(result, "CHALLENGE_FAILED");
    id = _safeMint(msg.sender);

    trophies[id] = Trophy(
      gas,
      challenge,
      program
    );
   
    {
      RecordStruct memory record = records[challenge];
      bool _isRecord;
      uint size = program.code.length;
      if (size < record.size || record.size == 0) {
        _isRecord = true;
        record.size = size;
      }
      if (gas < record.gas || record.gas == 0) {
        _isRecord = true;
        record.gas = gas;
      }

      if (_isRecord) {
        emit Record(challenge, program, size, gas);
        records[challenge] = record;
      }
    }

    uint value = funds[challenge];
    if (value > 0) {
      payable(msg.sender).transfer(value);
      funds[challenge] = 0;
      emit Payed(msg.sender, challenge, value);
    }
  }
}
