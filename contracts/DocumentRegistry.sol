// SPDX-License-Identifier: MIT

// Indicamos explícitamente la versión de Solidity que utiliza el contrato.
pragma solidity ^0.8.24;

/**
 * @title Registro de Documentos
 * @author Maximo Garmasar Vazquez
 *
 * @notice
 * Este contrato permite registrar documentos mediante su hash,
 * consultar si un documento fue registrado y registrar las wallets
 * que realizaron una firma sobre dicho documento.
 *
 * El documento original NO se almacena en blockchain.
 * Solamente almacenamos su hash, que funciona como una huella
 * digital del archivo.
 */
contract DocumentRegistry {

    // =============================================================
    //                          ESTRUCTURAS
    // =============================================================

    /**
     * @notice Representa un documento registrado en blockchain.
     *
     * documentHash: hash del documento.
     * creator: wallet que registró el documento.
     * createdAt: momento en que fue registrado.
     */
    struct Document {
        bytes32 documentHash;
        address creator;
        uint256 createdAt;
    }


    // =============================================================
    //                           MAPPINGS
    // =============================================================

    /**
     * @notice
     * Relaciona el hash de un documento con toda su información.
     *
     * Ejemplo conceptual:
     *
     * hashDocumento
     *      ↓
     * Document {
     *     hash,
     *     creador,
     *     fecha
     * }
     *
     * Utilizamos private porque el acceso a los documentos
     * se realizará mediante las funciones de consulta que
     * definimos más abajo.
     */
    mapping(bytes32 => Document) private documents;


    /**
     * @notice
     * Guarda las wallets que firmaron cada documento.
     *
     * Un documento puede tener múltiples firmantes.
     *
     * Ejemplo:
     *
     * hashDocumento
     *      ↓
     * [wallet1, wallet2, wallet3]
     */
    mapping(bytes32 => address[]) private signers;


    // =============================================================
    //                            EVENTOS
    // =============================================================

    /**
     * @notice
     * Se emite cada vez que se registra un nuevo documento.
     *
     * Los eventos permiten dejar un registro en los logs
     * de Ethereum y pueden ser utilizados posteriormente
     * por aplicaciones externas.
     */
    event DocumentRegistered(
        bytes32 indexed documentHash,
        address indexed creator,
        uint256 createdAt
    );


    /**
     * @notice
     * Se emite cada vez que una wallet firma un documento.
     */
    event DocumentSigned(
        bytes32 indexed documentHash,
        address indexed signer,
        uint256 timestamp
    );


    // =============================================================
    //                           MODIFIERS
    // =============================================================

    /**
     * @notice
     * Comprueba que el documento exista antes de ejecutar
     * una función que necesite trabajar con él.
     *
     * require() detiene la ejecución de la transacción
     * si la condición no se cumple.
     *
     * El símbolo "_" indica que, si la condición es correcta,
     * se continúa ejecutando la función que utiliza este modifier.
     */
    modifier documentExists(bytes32 documentHash) {

        require(
            documents[documentHash].createdAt != 0,
            "El documento no existe"
        );

        _;
    }


    // =============================================================
    //                    REGISTRAR DOCUMENTO
    // =============================================================

    /**
     * @notice
     * Registra un nuevo documento utilizando su hash.
     *
     * @param documentHash Hash del documento que queremos registrar.
     *
     * Esta función modifica el estado de la blockchain porque
     * agrega un nuevo documento al mapping.
     */
    function registerDocument(bytes32 documentHash)
        external
    {
        // Comprobamos que el documento todavía no haya sido registrado.
        require(
            documents[documentHash].createdAt == 0,
            "El documento ya esta registrado"
        );

        // Creamos y almacenamos el documento.
        documents[documentHash] = Document({
            documentHash: documentHash,

            // msg.sender representa la wallet que ejecutó
            // la transacción.
            creator: msg.sender,

            // block.timestamp representa el momento aproximado
            // en el que se ejecutó la transacción.
            createdAt: block.timestamp
        });

        // Emitimos un evento para dejar constancia del registro.
        emit DocumentRegistered(
            documentHash,
            msg.sender,
            block.timestamp
        );
    }


    // =============================================================
    //                       FIRMAR DOCUMENTO
    // =============================================================

    /**
     * @notice
     * Registra que la wallet que ejecuta la función
     * realizó una firma sobre el documento.
     *
     * @param documentHash Hash del documento que queremos firmar.
     *
     * La función utiliza el modifier documentExists para evitar
     * que alguien pueda firmar un documento que no fue registrado.
     */
    function signDocument(bytes32 documentHash)
        external
        documentExists(documentHash)
    {
        // Agregamos la wallet del usuario a la lista
        // de firmantes del documento.
        signers[documentHash].push(msg.sender);

        // Emitimos un evento indicando quién realizó la firma.
        emit DocumentSigned(
            documentHash,
            msg.sender,
            block.timestamp
        );
    }


    // =============================================================
    //                    VERIFICAR DOCUMENTO
    // =============================================================

    /**
     * @notice
     * Comprueba si existe un documento registrado con ese hash.
     * Esta función es view porque solamente consulta información
     *
     * @param documentHash Hash que queremos consultar.
     *
     * @return registrado True si el documento está registrado, false en caso contrario.
     */
    function verifyDocument(bytes32 documentHash)
        external
        view
        returns (bool)
    {
        return documents[documentHash].createdAt != 0;
    }


    // =============================================================
    //                    OBTENER DOCUMENTO
    // =============================================================

    /**
     * @notice
     * Devuelve la información de un documento registrado.
     *
     * @param documentHash Hash del documento que queremos consultar.
     *
     * @return Hash del documento.
     * @return Wallet que creó el registro.
     * @return Fecha de creación del registro.
     */
    function getDocument(bytes32 documentHash)
        external
        view
        documentExists(documentHash)
        returns (
            bytes32,
            address,
            uint256
        )
    {
        // Copiamos el documento a memoria para poder acceder
        // fácilmente a sus diferentes propiedades.
        Document memory document = documents[documentHash];

        return (
            document.documentHash,
            document.creator,
            document.createdAt
        );
    }


    // =============================================================
    //                     OBTENER FIRMANTES
    // =============================================================

    /**
     * @notice
     * Devuelve todas las wallets que firmaron un documento.
     *
     * @param documentHash Hash del documento que queremos consultar.
     *
     * @return Array con las direcciones de las wallets firmantes.
     */
    function getSigners(bytes32 documentHash)
        external
        view
        documentExists(documentHash)
        returns (address[] memory)
    {
        return signers[documentHash];
    }
}