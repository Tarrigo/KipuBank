// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title KipuBank
 * @author --
 * @notice Bóveda simple por usuario para ETH con límite global de depósitos y límite por retiro por transacción.
 * @dev Implementa buenas prácticas: errores personalizados, checks-effects-interactions, transfers seguras con call().
 */
contract KipuBank {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Se lanza cuando se pasa un monto 0 a una función que requiere > 0.
    error KipuBank_ZeroAmount();

    /// @notice Se lanza cuando los parámetros del constructor son inválidos (p.ej. 0).
    /// @param bankCap Param `bankCap` pasado al constructor.
    /// @param withdrawLimit Param `withdrawLimit` pasado al constructor.
    error KipuBank_InvalidConstructorParams(uint256 bankCap, uint256 withdrawLimit);

    /// @notice Se lanza cuando un depósito excede el límite global restante.
    /// @param attempted Monto intentado depositar.
    /// @param remainingCap Capacidad restante hasta `BANK_CAP`.
    error KipuBank_ExceedsBankCap(uint256 attempted, uint256 remainingCap);

    /// @notice Se lanza cuando un retiro excede el límite por transacción.
    /// @param attempted Monto intentado retirar.
    /// @param withdrawLimit Límite por retiro (inmutable).
    error KipuBank_ExceedsWithdrawLimit(uint256 attempted, uint256 withdrawLimit);

    /// @notice Se lanza cuando el usuario no tiene saldo suficiente.
    /// @param attempted Monto intentado retirar.
    /// @param balance Saldo actual del usuario.
    error KipuBank_InsufficientBalance(uint256 attempted, uint256 balance);

    /// @notice Se lanza cuando falla la transferencia nativa de ETH.
    error KipuBank_SendFailed();

    /// @notice Se lanza cuando se intenta enviar ETH directamente (sin usar deposit()).
    error KipuBank_DirectDepositNotAllowed();

    /*//////////////////////////////////////////////////////////////
                            IMMUTABLES / CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Límite por retiro por transacción (wei).
    uint256 public immutable WITHDRAW_LIMIT;

    /// @notice Límite global de depósitos en el banco (wei).
    uint256 public immutable BANK_CAP;

    /// @notice Dirección que desplegó el contrato.
    address public immutable DEPLOYER;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Saldos internos por dirección (wei).
    mapping(address => uint256) private _vaults;

    /// @notice Total de ETH depositado acumulado (wei).
    uint256 public totalDeposited;

    /// @notice Total de ETH retirado acumulado (wei).
    uint256 public totalWithdrawn;

    /// @notice Contador de depósitos exitosos.
    uint256 public depositCount;

    /// @notice Contador de retiros exitosos.
    uint256 public withdrawCount;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitido cuando un usuario deposita ETH.
    /// @param user Dirección del depositante.
    /// @param amount Monto depositado en wei.
    /// @param balanceAfter Saldo del usuario después del depósito.
    event Deposit(address indexed user, uint256 amount, uint256 balanceAfter);

    /// @notice Emitido cuando un usuario retira ETH.
    /// @param user Dirección del retirante.
    /// @param amount Monto retirado en wei.
    /// @param balanceAfter Saldo del usuario después del retiro.
    event Withdrawal(address indexed user, uint256 amount, uint256 balanceAfter);

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Valida que el monto sea mayor que 0.
    /// @param amount Monto a validar.
    modifier nonZero(uint256 amount) {
        if (amount == 0) revert KipuBank_ZeroAmount();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Inicializa KipuBank.
     * @param _bankCap Límite global de depósitos (en wei).
     * @param _withdrawLimit Límite máximo por retiro (en wei).
     * @dev Usa errores personalizados en lugar de require strings.
     */
    constructor(uint256 _bankCap, uint256 _withdrawLimit) {
        if (_bankCap == 0 || _withdrawLimit == 0) {
            revert KipuBank_InvalidConstructorParams({bankCap: _bankCap, withdrawLimit: _withdrawLimit});
        }

        BANK_CAP = _bankCap;
        WITHDRAW_LIMIT = _withdrawLimit;
        DEPLOYER = msg.sender;
    }

    /*//////////////////////////////////////////////////////////////
                              EXTERNAL / PAYABLE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deposita ETH en la bóveda del remitente.
     * @dev Requiere que `msg.value` > 0 y que no exceda la capacidad restante del banco.
     *      Llama a función privada que aplica los efectos (estado y eventos).
     */
    function deposit() external payable nonZero(msg.value) {
        uint256 amount = msg.value;

        uint256 remaining = _remainingCap();
        if (amount > remaining) {
            revert KipuBank_ExceedsBankCap({attempted: amount, remainingCap: remaining});
        }

        // Effects + events encapsulados en función privada.
        _applyDeposit(msg.sender, amount);
    }

    /**
     * @notice Retira ETH de la bóveda del remitente.
     * @param amount Cantidad en wei a retirar.
     * @dev Sigue checks-effects-interactions: actualiza estado antes de la interacción externa.
     */
    function withdraw(uint256 amount) external nonZero(amount) {
        if (amount > WITHDRAW_LIMIT) {
            revert KipuBank_ExceedsWithdrawLimit({attempted: amount, withdrawLimit: WITHDRAW_LIMIT});
        }

        uint256 userBalance = _vaults[msg.sender];
        if (amount > userBalance) {
            revert KipuBank_InsufficientBalance({attempted: amount, balance: userBalance});
        }

        // Effects
        _vaults[msg.sender] = userBalance - amount;
        totalWithdrawn += amount;
        withdrawCount += 1;

        // Interaction: enviar ETH de forma segura usando función privada.
        _safeSend(msg.sender, amount);

        emit Withdrawal(msg.sender, amount, _vaults[msg.sender]);
    }

    /*//////////////////////////////////////////////////////////////
                                VIEWS / EXTERNAL
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Devuelve el saldo interno de una dirección.
     * @param who Dirección a consultar.
     * @return balance Saldo en wei.
     */
    function getBalance(address who) external view returns (uint256 balance) {
        balance = _vaults[who];
    }

    /**
     * @notice Provee estadísticas públicas del banco.
     * @return _bankCap Límite global configurado (wei).
     * @return _withdrawLimit Límite por retiro por tx (wei).
     * @return _totalDeposited Total depositado acumulado (wei).
     * @return _totalWithdrawn Total retirado acumulado (wei).
     * @return _depositCount Número de depósitos.
     * @return _withdrawCount Número de retiros.
     */
    function getBankStats()
        external
        view
        returns (
            uint256 _bankCap,
            uint256 _withdrawLimit,
            uint256 _totalDeposited,
            uint256 _totalWithdrawn,
            uint256 _depositCount,
            uint256 _withdrawCount
        )
    {
        _bankCap = BANK_CAP;
        _withdrawLimit = WITHDRAW_LIMIT;
        _totalDeposited = totalDeposited;
        _totalWithdrawn = totalWithdrawn;
        _depositCount = depositCount;
        _withdrawCount = withdrawCount;
    }

    /*//////////////////////////////////////////////////////////////
                                PRIVATE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Calcula la capacidad restante antes de alcanzar `BANK_CAP`.
     * @dev Función privada view utilizada por deposit().
     * @return remaining Capacidad restante en wei.
     */
    function _remainingCap() private view returns (uint256 remaining) {
        // Safe: Solidity ^0.8.0 hace checks de underflow/overflow.
        remaining = BANK_CAP - totalDeposited;
    }

    /**
     * @notice Aplica cambios de estado y emite evento tras un depósito válido.
     * @param user Dirección que deposita.
     * @param amount Monto depositado en wei.
     * @dev Función privada para mantener lógica de efectos y emisión de eventos centralizada.
     */
    function _applyDeposit(address user, uint256 amount) private {
        _vaults[user] += amount;
        totalDeposited += amount;
        depositCount += 1;

        emit Deposit(user, amount, _vaults[user]);
    }

    /**
     * @notice Envía ETH de forma segura usando call() y revierte si falla.
     * @param to Dirección receptora.
     * @param amount Cantidad en wei a enviar.
     * @dev Función privada para aislar la interacción externa.
     */
    function _safeSend(address to, uint256 amount) private {
        (bool success, ) = to.call{value: amount}("");
        if (!success) revert KipuBank_SendFailed();
    }

    /*//////////////////////////////////////////////////////////////
                            RECEIVE / FALLBACK
    //////////////////////////////////////////////////////////////*/

    /// @notice Impide enviar ETH directamente sin usar deposit().
    receive() external payable {
        revert KipuBank_DirectDepositNotAllowed();
    }

    fallback() external payable {
        revert KipuBank_DirectDepositNotAllowed();
    }
}
