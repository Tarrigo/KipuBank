# 🏦 KipuBank

## 📘 Descripción

**KipuBank** es un contrato inteligente que funciona como una bóveda individual de ETH para cada usuario.  
Permite depósitos y retiros con control de límites y métricas internas, siguiendo las mejores prácticas de seguridad en Solidity.

**Características principales:**
- Balance interno por usuario.  
- Límite global de depósitos (`BANK_CAP`).  
- Límite máximo por retiro (`WITHDRAW_LIMIT`).  
- Emisión de eventos en cada operación.  
- Manejo de errores personalizados y patrón *checks-effects-interactions*.

---

## 🚀 Despliegue

**Red:** Sepolia Testnet  
**Compilador:** Solidity `^0.8.26`  
**Optimización:** activada (200 runs)

**Parámetros del constructor:**
- `BANK_CAP = 0.01 ether`  
- `WITHDRAW_LIMIT = 0.005 ether`

**Dirección del contrato:**
> `0x640be5cdffdd3c0fbecef2ce7efcd6a711249561`

🔗 [Ver en Etherscan](https://sepolia.etherscan.io/address/0x640be5cdffdd3c0fbecef2ce7efcd6a711249561)

🔧 Cómo desplegar nuevamente

1. Abrir [Remix IDE](https://remix.ethereum.org).
2. Compilar `KipuBank.sol` con Solidity `^0.8.26`.
3. En la pestaña “Deploy & Run Transactions”:
   - Seleccionar **Injected Provider - MetaMask** (Sepolia).
   - Ingresar los parámetros del constructor.
   - Confirmar la transacción en MetaMask.

   
---

## 💡 Funcionalidades principales

| Función | Descripción |
|----------|-------------|
| `deposit()` | Deposita ETH en tu bóveda (requiere enviar `msg.value > 0`). |
| `withdraw(uint256 amount)` | Retira fondos, limitado por `WITHDRAW_LIMIT` y tu balance. |
| `getBalance(address who)` | Consulta el saldo interno de un usuario. |
| `getBankStats()` | Devuelve estadísticas del banco (totales, límites, contadores). |

---

## 🧠 Ejemplo de uso rápido (Remix)

1. **Conectar MetaMask** a la red **Sepolia**.  
2. **Seleccionar** el contrato `KipuBank` en Remix.  
3. **Interactuar**:
   - Depositar → `deposit()` enviando ETH en el campo **Value**.  
   - Retirar → `withdraw(amount)` ingresando el monto en wei.  
   - Consultar → `getBalance(address)` o `getBankStats()`.

---

## 📜 Autoría

**Autor:** [@Tarrigo](https://github.com/Tarrigo)  
**Proyecto:** `KipuBank` — bóveda descentralizada de ETH  
**Licencia:** MIT
