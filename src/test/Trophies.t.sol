// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.13;
import "forge-std/Test.sol";
import {ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";
import {Id, Programs} from "../Programs.sol";
import {Challenge, Challenges} from "../Challenge.sol";
import {TrueChallenge, TrueProgram, TrueSlowProgram, FalseProgram} from "./Challenge.t.sol";
import {Trophy, Trophies} from "../Trophies.sol";

contract TrophiesTest is Test, ERC721TokenReceiver {
  using Id for address;

  event Transfer(address indexed from, address indexed to, uint256 indexed id);
  event Funded(address indexed challenge, uint value);
  event Payed(address indexed winner, address indexed challenge, uint value);
  event Created(uint id, address challenge, address program, uint size, uint gas);

  address trueChallenge;
  address trueProgram;
  address trueSlowProgram;
  address falseProgram;
  Challenges challenges;
  Programs programs;
  Trophies trophies;

  receive () external payable {}

  function setUp() public {
    challenges = new Challenges("Challenges", "CHALLENGES");
    trueChallenge = address(new TrueChallenge());
    programs = new Programs("Programs", "PROGRAMS");
    trueProgram = programs.write(type(TrueProgram).creationCode);
    trueSlowProgram = programs.write(type(TrueSlowProgram).creationCode);
    falseProgram = programs.write(type(FalseProgram).creationCode);
    trophies = new Trophies("Trophies", "TROPHIES", address(challenges), address(programs));
  }

  function testFund(uint value) public {
    value %= address(this).balance;

    vm.expectRevert("CHALLENGE_NOT_ACCEPTED");
    trophies.fund{value: value}(trueChallenge);

    challenges.requestChallenge(trueChallenge, "function which returns true");

    vm.expectRevert("CHALLENGE_NOT_ACCEPTED");
    trophies.fund{value: value}(trueChallenge);

    challenges.reviewChallenge(trueChallenge.id(), true, "accepted");

    if (value == 0) {
      vm.expectRevert("NO_VALUE");
      trophies.fund{value: value}(trueChallenge);
    } else {
      vm.expectEmit(true, false, false, true);
      emit Funded(trueChallenge, value);
      trophies.fund{value: value}(trueChallenge);
      assertEq(address(trophies).balance, value);
      assertEq(trophies.funds(trueChallenge), value);
    }
  }

  function testSubmit() public {
    challenges.requestChallenge(trueChallenge, "function which returns true");

    vm.expectRevert("CHALLENGE_NOT_ACCEPTED");
    trophies.submit(trueChallenge, trueProgram);

    challenges.reviewChallenge(trueChallenge.id(), true, "accepted");

    vm.expectRevert("CHALLENGE_FAILED");
    trophies.submit(trueChallenge, falseProgram);

    vm.expectEmit(true, true, true, false);
    emit Transfer(address(0), address(this), trophies.totalSupply());
    vm.expectEmit(true, true, true, false);
    emit Created(0, trueChallenge, trueSlowProgram, trueSlowProgram.code.length, 0);
    uint id = trophies.submit(trueChallenge, trueSlowProgram);
    assertEq(trophies.ownerOf(id), address(this));
    assertEq(trophies.balanceOf(address(this)), 1);
    (bool recordSize, bool recordGas) = trophies.isRecord(id);
    assertTrue(recordSize);
    assertTrue(recordGas);

    vm.expectEmit(true, true, true, true);
    emit Transfer(address(0), address(this), trophies.totalSupply());
    vm.expectEmit(true, true, true, false);
    emit Created(1, trueChallenge, trueProgram, trueProgram.code.length, 0);
    uint id1 = trophies.submit(trueChallenge, trueProgram);
    assertEq(trophies.ownerOf(id1), address(this));
    assertEq(trophies.balanceOf(address(this)), 2);
    (recordSize, recordGas) = trophies.isRecord(id);
    assertTrue(!recordSize);
    assertTrue(!recordGas);
    (recordSize, recordGas) = trophies.isRecord(id1);
    assertTrue(recordSize);
    assertTrue(recordGas);
  }

  function testLogTokenURI() public {
    challenges.requestChallenge(trueChallenge, "function which returns true");
    challenges.reviewChallenge(trueChallenge.id(), true, "accepted");
    uint id = trophies.submit(trueChallenge, trueProgram);
    emit log(trophies.tokenURI(id));
  }
}
