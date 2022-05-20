// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.13;
import "forge-std/Test.sol";
import "../Programs.sol";
import {Create2} from "create2/Create2.sol";
import "samples/Samples.sol";

contract ProgramsMixin is Test {
  Programs programs;

  function setUp() public virtual {
    programs = new Programs("Programs", "PROG");
  }
}

contract ProgramsTest is ProgramsMixin {
  using Id for address;
  using Create2 for address;

  event Transfer(address indexed from, address indexed to, uint256 indexed id);

  function testGasDeploy() public {
    new Programs("Programs", "PROG");
  }

  function testOwnerOf() public {
    assertEq(programs.ownerOf(address(programs).id()), address(this));
  }

  function testWriteEmpty() public {
    bytes memory text = type(Empty).creationCode;
    vm.expectEmit(true, true, true, false);
    emit Transfer(address(0), address(this), address(programs).create2Address(programs.salt(), text).id());
    address program = programs.write(text);
    assertEq0(type(Empty).runtimeCode, program.code);
    assertEq(programs.ownerOf(program.id()), address(this));
    assertGt(bytes(programs.tokenURI(program.id())).length, 0);

    bytes memory textB = type(Identity).creationCode;
    address programB = programs.write(textB);
    assertEq(programs.ownerOf(uint(uint160(programB))), address(this));
  }

  function testLogTokenURI() public {
    address program = programs.write(type(Empty).creationCode);
    emit log(programs.tokenURI(program.id()));
  }

  function testDoubleWrite() public {
    bytes memory text = type(Empty).creationCode;
    programs.write(text);

    vm.expectRevert(ProgramExists.selector);
    programs.write(text);
  }

  function testGasWriteEmpty() public {
    programs.write(type(Empty).creationCode);
  }

  function testGasWriteIdentity() public {
    programs.write(type(Identity).creationCode);
  }

  function testGasWriteAdd() public {
    programs.write(type(Add).creationCode);
  }

  function testGasWriteSub() public {
    programs.write(type(Sub).creationCode);
  }

  function testGasWriteReturnEth() public {
    programs.write(type(ReturnEth).creationCode);
  }
}

contract ProgramsWithEmptyTest is ProgramsMixin {
  function setUp() public virtual override {
    super.setUp();
    programs.write(type(Empty).creationCode);
  }

  function testGasWriteIdentity() public {
    programs.write(type(Identity).creationCode);
  }

  function testGasWriteAdd() public {
    programs.write(type(Add).creationCode);
  }

  function testGasWriteSub() public {
    programs.write(type(Sub).creationCode);
  }

  function testGasWriteReturnEth() public {
    programs.write(type(ReturnEth).creationCode);
  }
}

contract ProgramsWithEmptyAddTest is ProgramsMixin {
  function setUp() public virtual override {
    super.setUp();
    programs.write(type(Empty).creationCode);
    programs.write(type(Add).creationCode);
  }

  function testGasWriteIdentity() public {
    programs.write(type(Identity).creationCode);
  }

  function testGasWriteSub() public {
    programs.write(type(Sub).creationCode);
  }

  function testGasWriteReturnEth() public {
    programs.write(type(ReturnEth).creationCode);
  }
}
