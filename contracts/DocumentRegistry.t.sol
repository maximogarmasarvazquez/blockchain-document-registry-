// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {DocumentRegistry} from "./DocumentRegistry.sol";
import {Test} from "forge-std/Test.sol";

contract DocumentRegistryTest is Test {
    DocumentRegistry registry;

    bytes32 constant DOC_HASH = keccak256("documento-prueba");
    bytes32 constant DOC_HASH_2 = keccak256("otro-documento");
    address constant SIGNER = address(0x1234);
    address constant OTHER_SIGNER = address(0x5678);

    function setUp() public {
        registry = new DocumentRegistry();
    }

    function test_RegisterDocument() public {
        registry.registerDocument(DOC_HASH);

        assertTrue(registry.verifyDocument(DOC_HASH), "Document should exist after registration");
    }

    function testFuzz_RegisterDocument(bytes32 hash) public {
        vm.assume(hash != bytes32(0));

        registry.registerDocument(hash);

        assertTrue(registry.verifyDocument(hash), "Document should exist after registration");
    }

    function test_RevertOnDuplicateRegistration() public {
        registry.registerDocument(DOC_HASH);

        vm.expectRevert("El documento ya esta registrado");
        registry.registerDocument(DOC_HASH);
    }

    function test_RegisterDocumentEmitsEvent() public {
        vm.expectEmit(true, true, true, true);
        emit DocumentRegistry.DocumentRegistered(DOC_HASH, address(this), block.timestamp);

        registry.registerDocument(DOC_HASH);
    }

    function test_SignDocument() public {
        registry.registerDocument(DOC_HASH);

        vm.prank(SIGNER);
        registry.signDocument(DOC_HASH);

        address[] memory signers = registry.getSigners(DOC_HASH);
        assertEq(signers.length, 1, "Should have one signer");
        assertEq(signers[0], SIGNER, "Signer should be registered");
    }

    function test_SignDocumentWithMultipleSigners() public {
        registry.registerDocument(DOC_HASH);

        vm.prank(SIGNER);
        registry.signDocument(DOC_HASH);

        vm.prank(OTHER_SIGNER);
        registry.signDocument(DOC_HASH);

        address[] memory signers = registry.getSigners(DOC_HASH);
        assertEq(signers.length, 2, "Should have two signers");
        assertEq(signers[0], SIGNER, "First signer should be SIGNER");
        assertEq(signers[1], OTHER_SIGNER, "Second signer should be OTHER_SIGNER");
    }

    function test_RevertOnSignNonExistentDocument() public {
        vm.expectRevert("El documento no existe");
        registry.signDocument(DOC_HASH);
    }

    function test_SignDocumentEmitsEvent() public {
        registry.registerDocument(DOC_HASH);

        vm.expectEmit(true, true, true, true);
        emit DocumentRegistry.DocumentSigned(DOC_HASH, SIGNER, block.timestamp);

        vm.prank(SIGNER);
        registry.signDocument(DOC_HASH);
    }

    function test_VerifyNonExistentDocument() public view {
        assertFalse(registry.verifyDocument(DOC_HASH), "Document should not exist");
    }

    function test_GetDocument() public {
        registry.registerDocument(DOC_HASH);

        (
            bytes32 returnedHash,
            address creator,
            uint256 createdAt
        ) = registry.getDocument(DOC_HASH);

        assertEq(returnedHash, DOC_HASH, "Returned hash should match");
        assertEq(creator, address(this), "Creator should be the caller");
        assertEq(createdAt, block.timestamp, "CreatedAt should match block timestamp");
    }

    function test_RevertOnGetNonExistentDocument() public {
        vm.expectRevert("El documento no existe");
        registry.getDocument(DOC_HASH);
    }

    function test_GetSignersOnEmptyDocument() public {
        registry.registerDocument(DOC_HASH);

        address[] memory signers = registry.getSigners(DOC_HASH);
        assertEq(signers.length, 0, "Should have no signers initially");
    }

    function test_RevertOnGetSignersNonExistentDocument() public {
        vm.expectRevert("El documento no existe");
        registry.getSigners(DOC_HASH);
    }

    function test_MultipleDocumentsTrackedIndependently() public {
        registry.registerDocument(DOC_HASH);

        vm.prank(SIGNER);
        registry.signDocument(DOC_HASH);

        registry.registerDocument(DOC_HASH_2);

        assertTrue(registry.verifyDocument(DOC_HASH), "First document should exist");
        assertTrue(registry.verifyDocument(DOC_HASH_2), "Second document should exist");

        address[] memory signers1 = registry.getSigners(DOC_HASH);
        address[] memory signers2 = registry.getSigners(DOC_HASH_2);

        assertEq(signers1.length, 1, "First document should have one signer");
        assertEq(signers2.length, 0, "Second document should have no signers");
    }
}
