// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Importamos el contrato que vamos a probar.
import {DocumentRegistry} from "./DocumentRegistry.sol";
// Importamos la librería de testing (forge-std) que trae las
// cheatcodes de "vm" y las aserciones (assertTrue, assertEq, etc).
import {Test} from "forge-std/Test.sol";

// "is Test" hace que nuestro contrato herede todas las herramientas
// de medición: vm (para manipular el EVM simulado) y los assert*.
contract DocumentRegistryTest is Test {
    // Instancia del contrato que vamos a testear.
    DocumentRegistry registry;

    // Hashes "de mentira" que usamos como si fueran documentos reales.
    bytes32 constant DOC_HASH = keccak256("documento-prueba");
    bytes32 constant DOC_HASH_2 = keccak256("otro-documento");
    // Direcciones ficticias que usamos para simular otras wallets.
    address constant SIGNER = address(0x1234);
    address constant OTHER_SIGNER = address(0x5678);

    // setUp() se ejecuta antes de CADA test: despliega un contrato nuevo.
    // Así cada prueba arranca con la base limpia y no comparte estado.
    function setUp() public {
        registry = new DocumentRegistry();
    }

    // Test 1: registrar un documento y comprobar que quedó guardado.
    // Llamamos a registerDocument con un hash y luego verificamos
    // que verifyDocument responda true para ese mismo hash.
    function test_RegisterDocument() public {
        registry.registerDocument(DOC_HASH);

        assertTrue(registry.verifyDocument(DOC_HASH), "El documento debe existir despues de registrarse");
    }

    // Test de fuzzing: Hardhat repite esta prueba con 256 hashes
    // aleatorios para asegurarse de que el registro funciona con
    // cualquier valor. vm.assume descarta el hash 0x0, que es el
    // marcador que el contrato usa para saber si existe o no.
    function testFuzz_RegisterDocument(bytes32 hash) public {
        vm.assume(hash != bytes32(0));

        registry.registerDocument(hash);

        assertTrue(registry.verifyDocument(hash), "El documento debe existir despues de registrarse");
    }

    // Test de error: no se puede registrar el MISMO hash dos veces.
    // El primer registro sale bien; el segundo debe fallar (revert)
    // con el mensaje exacto que definimos en el contrato.
    function test_RevertOnDuplicateRegistration() public {
        registry.registerDocument(DOC_HASH);

        // Le decimos al test: "la próxima llamada DEBE fallar".
        vm.expectRevert("El documento ya esta registrado");
        registry.registerDocument(DOC_HASH);
    }

    // Test de evento: cuando se registra un documento se debe emitir
    // DocumentRegistered con los datos correctos.
    // vm.expectEmit compara el evento que emite el contrato con el
    // que nosotros emitimos en el test: si no coincide, falla.
    function test_RegisterDocumentEmitsEvent() public {
        // address(this) es el propio contrato de test: como no usamos
        // vm.prank, el que llama a registerDocument es este test.
        vm.expectEmit(true, true, true, true);
        emit DocumentRegistry.DocumentRegistered(DOC_HASH, address(this), block.timestamp);

        registry.registerDocument(DOC_HASH);
    }

    // Test de firma: vm.prank(SIGNER) "le hace creer" al contrato que
    // la llamada viene de la wallet 0x1234. Así simulamos que fue otro
    // usuario quien firmó, sin necesidad de una wallet real.
    function test_SignDocument() public {
        registry.registerDocument(DOC_HASH);

        // A partir de la próxima llamada, msg.sender será 0x1234.
        vm.prank(SIGNER);
        registry.signDocument(DOC_HASH);

        // Consultamos los firmantes y comprobamos que haya 1 y que
        // sea exactamente 0x1234.
        address[] memory signers = registry.getSigners(DOC_HASH);
        assertEq(signers.length, 1, "Deberia haber un firmante");
        assertEq(signers[0], SIGNER, "El firmante deberia ser SIGNER");
    }

    // Test de firmas multiples: dos wallets distintas firman el mismo
    // documento y ambas deben quedar en la lista, en orden.
    function test_SignDocumentWithMultipleSigners() public {
        registry.registerDocument(DOC_HASH);

        vm.prank(SIGNER);
        registry.signDocument(DOC_HASH);

        vm.prank(OTHER_SIGNER);
        registry.signDocument(DOC_HASH);

        address[] memory signers = registry.getSigners(DOC_HASH);
        assertEq(signers.length, 2, "Deberia haber dos firmantes");
        assertEq(signers[0], SIGNER, "El primer firmante deberia ser SIGNER");
        assertEq(signers[1], OTHER_SIGNER, "El segundo firmante deberia ser OTHER_SIGNER");
    }

    // Test de error: firmar un documento que nunca se registró
    // debe fallar con el mensaje "El documento no existe".
    function test_RevertOnSignNonExistentDocument() public {
        vm.expectRevert("El documento no existe");
        registry.signDocument(DOC_HASH);
    }

    // Test de evento de firma: al firmar se debe emitir DocumentSigned
    // con el hash y la wallet que firmó.
    function test_SignDocumentEmitsEvent() public {
        registry.registerDocument(DOC_HASH);

        vm.expectEmit(true, true, true, true);
        emit DocumentRegistry.DocumentSigned(DOC_HASH, SIGNER, block.timestamp);

        vm.prank(SIGNER);
        registry.signDocument(DOC_HASH);
    }

    // Test de consulta: antes de registrar nada, verifyDocument debe
    // devolver false (el documento todavía no existe).
    function test_VerifyNonExistentDocument() public view {
        assertFalse(registry.verifyDocument(DOC_HASH), "El documento no deberia existir");
    }

    // Test de getDocument: registramos, consultamos y comprobamos
    // que devuelve los 3 datos correctos: hash, creador y fecha.
    // El creador es address(this) porque no hubo prank, y la fecha
    // debe coincidir con block.timestamp del momento del registro.
    function test_GetDocument() public {
        registry.registerDocument(DOC_HASH);

        (
            bytes32 returnedHash,
            address creator,
            uint256 createdAt
        ) = registry.getDocument(DOC_HASH);

        assertEq(returnedHash, DOC_HASH, "El hash devuelto deberia coincidir");
        assertEq(creator, address(this), "El creador deberia ser quien llamo");
        assertEq(createdAt, block.timestamp, "La fecha deberia coincidir con el bloque");
    }

    // Test de error: consultar un documento inexistente con getDocument
    // debe fallar.
    function test_RevertOnGetNonExistentDocument() public {
        vm.expectRevert("El documento no existe");
        registry.getDocument(DOC_HASH);
    }

    // Test de consulta: un documento recién registrado todavía no
    // tiene firmantes, así que getSigners debe devolver lista vacía.
    function test_GetSignersOnEmptyDocument() public {
        registry.registerDocument(DOC_HASH);

        address[] memory signers = registry.getSigners(DOC_HASH);
        assertEq(signers.length, 0, "No deberia haber firmantes al inicio");
    }

    // Test de error: pedir los firmantes de un documento inexistente
    // debe fallar.
    function test_RevertOnGetSignersNonExistentDocument() public {
        vm.expectRevert("El documento no existe");
        registry.getSigners(DOC_HASH);
    }

    // Test final: demostrar que cada documento es independiente.
    // Registramos DOC_HASH y lo firmamos; luego registramos DOC_HASH_2
    // y comprobamos que los signers de uno no se mezclan con el otro.
    function test_MultipleDocumentsTrackedIndependently() public {
        registry.registerDocument(DOC_HASH);

        vm.prank(SIGNER);
        registry.signDocument(DOC_HASH);

        registry.registerDocument(DOC_HASH_2);

        assertTrue(registry.verifyDocument(DOC_HASH), "El primer documento deberia existir");
        assertTrue(registry.verifyDocument(DOC_HASH_2), "El segundo documento deberia existir");

        // Cada hash tiene su propia lista de firmantes.
        address[] memory signers1 = registry.getSigners(DOC_HASH);
        address[] memory signers2 = registry.getSigners(DOC_HASH_2);

        assertEq(signers1.length, 1, "El primer documento deberia tener un firmante");
        assertEq(signers2.length, 0, "El segundo documento no deberia tener firmantes");
    }
}