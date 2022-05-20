// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.13;
import "forge-std/Test.sol";
import {ERC721TokenReceiver} from "solmate/tokens/ERC721.sol";
import {Id} from "../Programs.sol";
import {Challenge, Challenges} from "../Challenge.sol";

interface TrueInterface {
  function returnTrue() external returns (bool);
}

contract TrueChallenge is Challenge {
  function challenge(address program) external override returns (bool) {
    return TrueInterface(program).returnTrue();
  }
}

contract TrueProgram {
  function returnTrue() external returns (bool) {
    return true;
  }
}

contract TrueSlowProgram {
  uint trials;

  function returnTrue() external returns (bool) {
    trials++;
    return true;
  }
}

contract FalseProgram {
  function returnTrue() external returns (bool) {
    return false;
  }
}

contract ChallengesTest is Test, ERC721TokenReceiver {
  using Id for address;

  event Transfer(address indexed from, address indexed to, uint256 indexed id);
  event AcceptChallenge(uint indexed id, bool accepted, bytes message);

  address trueChallenge;
  Challenges challenges;

  function setUp() public {
    challenges = new Challenges("Challenges", "CHALLENGES");
    trueChallenge = address(new TrueChallenge());
  }

  function testLogTokenURI() public {
    challenges.requestChallenge(trueChallenge, "function which returns true");
    emit log(challenges.tokenURI(trueChallenge.id()));
  }

  function testRequestChallenge() public {
    vm.expectEmit(true, true, true, false);
    emit Transfer(address(0), address(this), trueChallenge.id());
    challenges.requestChallenge(trueChallenge, "function which returns true");
    assertEq(challenges.ownerOf(trueChallenge.id()), address(this));
    assertEq(challenges.balanceOf(address(this)), 1);
    assertTrue(!challenges.accepted(trueChallenge.id()));
    assertGt(bytes(challenges.tokenURI(trueChallenge.id())).length, 0);
  }

  function testReviewChallenge(bool accepted, bytes calldata message) public {
    challenges.requestChallenge(trueChallenge, "function which returns true");

    vm.expectRevert("UNAUTHORIZED");
    vm.prank(address(1));
    challenges.reviewChallenge(trueChallenge.id(), accepted, message);

    vm.expectEmit(true, true, true, true);
    emit AcceptChallenge(trueChallenge.id(), accepted, message);
    challenges.reviewChallenge(trueChallenge.id(), accepted, message);
    if (accepted) {
      assertEq(challenges.ownerOf(trueChallenge.id()), address(this));
      assertEq(challenges.balanceOf(address(this)), 1);
      assertTrue(challenges.accepted(trueChallenge.id()));
      assertGt(bytes(challenges.tokenURI(trueChallenge.id())).length, 0);
    } else {
      vm.expectRevert("NOT_MINTED");
      assertEq(challenges.ownerOf(trueChallenge.id()), address(0));
      assertEq(challenges.balanceOf(address(this)), 0);
      assertTrue(!challenges.accepted(trueChallenge.id()));
      vm.expectRevert("NOT_MINTED");
      assertEq(bytes(challenges.tokenURI(trueChallenge.id())).length, 0);
    }
  }
}
