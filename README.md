# Blockchain Document Registry

Registro, firma y verificación de documentos sobre Ethereum (Sepolia).

Un contrato inteligente en Solidity que actúa como un **registro público de documentos**. En lugar de guardar el archivo completo en la blockchain, el contrato guarda su **huella digital (hash keccak256)**, junto con la wallet que lo registró, la fecha y la lista de wallets que lo firmaron. Cualquier persona puede comprobar después si un archivo es exactamente el mismo que fue registrado: alcanza con recalcular su hash y consultar el contrato.

> El documento original **nunca** se publica en blockchain: solo se guarda su hash.

Repositorio: <https://github.com/maximogarmasarvazquez/blockchain-document-registry->

---

## Requisitos previos

- **Node.js 22** (como usa el CI) o superior. → <https://nodejs.org>
- Una wallet (MetaMask u otra) conectada a la red **Sepolia** con ETH de prueba (se consigue gratis con un faucet).
- Para los pasos de Etherscan no hace falta instalar nada: solo un navegador con MetaMask.

Instalá las dependencias del proyecto:

```shell
npm ci
```

(O con `npm install` si es la primera vez.)

---

## 1) Generar el hash de un documento (herramienta HTML)

La herramienta `tools/hash-generator.html` genera el hash **keccak256** de un archivo y también permite verificar que un archivo coincide con un hash dado. No envía el archivo a ningún servidor: todo el cálculo ocurre en tu navegador. Es un archivo **autocontenido** (la implementación de keccak256 va embebida), por lo que funciona sin dependencias externas ni conexión a internet.

**Abrir la herramienta:**

- **Opción 1 (sin instalar nada):** [Abrir Hash Generator en tu navegador](https://htmlpreview.github.io/?https://github.com/maximogarmasarvazquez/blockchain-document-registry-/blob/main/tools/hash-generator.html)
- **Opción 2 (local):** descargá/cloná el repo y abrí el archivo con el navegador (doble clic):

  ```shell
  git clone https://github.com/maximogarmasarvazquez/blockchain-document-registry-.git
  cd blockchain-document-registry-
  start tools/hash-generator.html
  ```

**Generar el hash:**

1. En la pestaña **“Generar Hash”**, arrastrá el documento a la zona punteada o buscalo en tu PC.
2. Clic en **“Copiar”** para quedarte con el hash (un `0x...` de 66 caracteres).

**Comprobar que funciona** (se puede hacer sin tocar blockchain):

- La misma pestaña de **“Verificar Documento”**: pegá el hash y volvé a arrastrar el archivo original → debe decir *¡El hash coincide!*.
- Modificá el archivo en cualquier byte (cambiá una letra) y verificalo con el mismo hash → *El hash NO coincide*.
- Repetí con documentos distintos → los hashes siempre son distintos.

Esto funciona porque keccak256 es determinista y sensible a cualquier cambio: **un byte distinto produce un hash completamente distinto**.

---

## 2) Correr los tests (los simuladores del usuario)

Los tests de Solidity (`contracts/DocumentRegistry.t.sol`) se escribieron en estilo **Foundry (forge-std)** y Hardhat 3 los ejecuta sobre su **EVM simulado** (no gastan gas ni tocan una red real). Son **14 tests** + 1 de fuzzing.

Para ejecutarlos:

```shell
npx hardhat test
```

O únicamente los de Solidity:

```shell
npx hardhat test solidity
```

### ¿Cómo “simulan” a un usuario?

- Por defecto, el llamador de cada función es el **propio contrato de test** (`address(this)`): es el primer “usuario” que registra el documento.
- `vm.prank(0x1234)` **impersona a otra wallet**: cambia `msg.sender` para la siguiente llamada, simulando que fue un usuario distinto quien firmó.
- `vm.expectRevert("El documento no existe")` verifica que la transacción **falle** con ese error (casos de error).
- `vm.expectEmit` verifica que se emita el **evento** correcto (`DocumentRegistered`, `DocumentSigned`).
- `testFuzz_RegisterDocument(bytes32 hash)` corre la misma prueba con **256 hashes aleatorios** (con `vm.assume` descartando el hash inválido `0x0`).

Es decir: no hay un cliente/meta-máscara real, el test **prankea** distintas direcciones para cubrir registros, firmas, eventos, errores y múltiples firmantes.

---

## 3) Usar el contrato en Etherscan (el camino principal)

El contrato está **desplegado y verificado** en Sepolia, así que cualquier persona puede interactuar sin compilar ni desplegar nada:

- Contrato verificado: <https://sepolia.etherscan.io/address/0x10918E1D95bedBbeC8F66a3eC5A257b163197c1D>
- Transacción de despliegue: <https://sepolia.etherscan.io/tx/0x20c0c52c86491cc1d89911d0a6e2f0c5509249e007735850826759b9c933f21e>

### Paso A — Registrar un documento

1. Generá el hash de tu documento con la [herramienta](#1-generar-el-hash-de-un-documento-herramienta-html) y copialo.
2. Andá a **Contract → Write Contract** en Etherscan y conectá tu wallet (MetaMask).
3. En `registerDocument`, pegá el hash (`0x...`) y confirmá con **Write**.
4. Confirmá la transacción en MetaMask. El documento queda registrado y se emite el evento `DocumentRegistered`.

### Paso B — Firmar el documento

1. En **Write Contract**, usá la función `signDocument` con el **mismo hash**.
2. Confirmá. Tu wallet queda agregada como firmante (evento `DocumentSigned`).

### Paso C — Verificar

En **Contract → Read Contract** (no requiere wallet):

- `verifyDocument(hash)` → `true` si el documento está registrado.
- `getDocument(hash)` → creó el registro, quién y cuándo (`createdAt`).
- `getSigners(hash)` → lista de wallets que lo firmaron.
- Para verificar la **integridad del archivo**, recalculá su hash con la [herramienta](#1-generar-el-hash-de-un-documento-herramienta-html) y comparalo: si el archivo cambió en algún byte, el hash deja de coincidir con el registrado.

---

## 4) Desplegar el contrato (solo quien quiera re-desplegarlo)

```shell
cp .env.example .env
```

Completá `.env` (RPC de Sepolia, clave privada de la wallet —solo testnet— y API key de Etherscan). Nunca subas `.env` al repositorio: está en `.gitignore`.

```shell
npx hardhat ignition deploy ignition/modules/DocumentRegistry.ts --network sepolia
npx hardhat verify --network sepolia <DIRECCION_DESPLEGADA>
```

---

## 5) Integración continua (CI)

El workflow de GitHub Actions está en `.github/workflows/ci.yml`.

### ¿Cómo funciona?

- Se ejecuta **automáticamente** en cada **push a `main`** y en cada **pull request**.
- No hay que hacer nada manual: al empujar el código a GitHub, el CI corre solo.

### ¿Qué hace?

1. `actions/checkout@v4` — descarga el repositorio.
2. `actions/setup-node@v4` con **Node 22**.
3. `npm ci` — instala las dependencias exactas del `package-lock.json`.
4. `npm test` (equivale a `npx hardhat test`) — ejecuta las **14 pruebas de Solidity en el EVM simulado** de Hardhat.


## Datos del despliegue (verificados en Sepolia Etherscan)

| Dato | Valor |
|---|---|
| Red | Ethereum Sepolia |
| Dirección del contrato | `0x10918E1D95bedBbeC8F66a3eC5A257b163197c1D` |
| Transacción de despliegue | `0x20c0c52c86491cc1d89911d0a6e2f0c5509249e007735850826759b9c933f21e` |
| Bloque | `11655380` — 07/09/2026 16:38:48 UTC |
| Wallet firmante | `0x9C242D0bd62f4e4A9dD6153a3e13E29903904C70` |
| Compilador | Solidity `v0.8.28` (pragma `^0.8.24`), optimizer `200 runs` |
| Verificación | Etherscan — *Source Code Verified (Exact Match)* |

---

## Estructura del proyecto

```
contracts/                 Código del contrato y tests Solidty
  DocumentRegistry.sol     Contrato de registro de documentos
  DocumentRegistry.t.sol   14 tests Foundry + fuzzing
ignition/modules/          Módulo de despliegue de Hardhat Ignition
tools/                     Herramienta HTML para generar/verificar hashes
.github/workflows/ci.yml   Pipeline de CI (GitHub Actions)
```

## Limitaciones

- El hash prueba **integridad**, no contenido: un documento falso registrado sigue siendo un documento registrado.
- La blockchain prueba que una **dirección** hizo la operación, no **quién** es la persona detrás de ella (no hay verificación de identidad, queda como evolución futura).
- El documento completo no se almacena en la red; guardar el archivo en storage descentralizado (IPFS, etc.) queda como trabajo futuro.
- Es una red de **prueba**: los registros en Sepolia pueden perderse en un reset de la testnet.