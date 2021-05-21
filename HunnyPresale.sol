// Dependency file: @pancakeswap/pancake-swap-lib/contracts/math/SafeMath.sol

// SPDX-License-Identifier: MIT

// pragma solidity >=0.4.0;

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, 'SafeMath: addition overflow');

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, 'SafeMath: subtraction overflow');
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, 'SafeMath: multiplication overflow');

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, 'SafeMath: division by zero');
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, 'SafeMath: modulo by zero');
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }

    function min(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x < y ? x : y;
    }

    // babylonian method (https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method)
    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}


// Dependency file: @pancakeswap/pancake-swap-lib/contracts/GSN/Context.sol


// pragma solidity >=0.4.0;

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with GSN meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
contract Context {
    // Empty internal constructor, to prevent people from mistakenly deploying
    // an instance of this contract, which should be used via inheritance.
    constructor() internal {}

    function _msgSender() internal view returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}


// Dependency file: @pancakeswap/pancake-swap-lib/contracts/access/Ownable.sol


// pragma solidity >=0.4.0;

// import '/home/pmtoan/workspace/snapinnovations/pancakehunny/hunny/node_modules/@pancakeswap/pancake-swap-lib/contracts/GSN/Context.sol';

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() internal {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(_owner == _msgSender(), 'Ownable: caller is not the owner');
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     */
    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0), 'Ownable: new owner is the zero address');
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}


// Dependency file: @pancakeswap/pancake-swap-lib/contracts/token/BEP20/IBEP20.sol


// pragma solidity >=0.4.0;

interface IBEP20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the token decimals.
     */
    function decimals() external view returns (uint8);

    /**
     * @dev Returns the token symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the token name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the bep token owner.
     */
    function getOwner() external view returns (address);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address _owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}


// Dependency file: @pancakeswap/pancake-swap-lib/contracts/utils/Address.sol


// pragma solidity ^0.6.2;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // According to EIP-1052, 0x0 is the value returned for not-yet created accounts
        // and 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470 is returned
        // for accounts without code, i.e. `keccak256('')`
        bytes32 codehash;
        bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            codehash := extcodehash(account)
        }
        return (codehash != accountHash && codehash != 0x0);
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, 'Address: insufficient balance');

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{value: amount}('');
        require(success, 'Address: unable to send value, recipient may have reverted');
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain`call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, 'Address: low-level call failed');
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return _functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, 'Address: low-level call with value failed');
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, 'Address: insufficient balance for call');
        return _functionCallWithValue(target, data, value, errorMessage);
    }

    function _functionCallWithValue(
        address target,
        bytes memory data,
        uint256 weiValue,
        string memory errorMessage
    ) private returns (bytes memory) {
        require(isContract(target), 'Address: call to non-contract');

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{value: weiValue}(data);
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                // solhint-disable-next-line no-inline-assembly
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}


// Dependency file: @pancakeswap/pancake-swap-lib/contracts/token/BEP20/SafeBEP20.sol


// pragma solidity ^0.6.0;

// import '/home/pmtoan/workspace/snapinnovations/pancakehunny/hunny/node_modules/@pancakeswap/pancake-swap-lib/contracts/token/BEP20/IBEP20.sol';
// import '/home/pmtoan/workspace/snapinnovations/pancakehunny/hunny/node_modules/@pancakeswap/pancake-swap-lib/contracts/math/SafeMath.sol';
// import '/home/pmtoan/workspace/snapinnovations/pancakehunny/hunny/node_modules/@pancakeswap/pancake-swap-lib/contracts/utils/Address.sol';

/**
 * @title SafeBEP20
 * @dev Wrappers around BEP20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeBEP20 for IBEP20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeBEP20 {
    using SafeMath for uint256;
    using Address for address;

    function safeTransfer(
        IBEP20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IBEP20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IBEP20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(
        IBEP20 token,
        address spender,
        uint256 value
    ) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        // solhint-disable-next-line max-line-length
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            'SafeBEP20: approve from non-zero to non-zero allowance'
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(
        IBEP20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender).add(value);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IBEP20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender).sub(
            value,
            'SafeBEP20: decreased allowance below zero'
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IBEP20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, 'SafeBEP20: low-level call failed');
        if (returndata.length > 0) {
            // Return data is optional
            // solhint-disable-next-line max-line-length
            require(abi.decode(returndata, (bool)), 'SafeBEP20: BEP20 operation did not succeed');
        }
    }
}


// Dependency file: contracts/Constants.sol

// pragma solidity 0.6.12;


library Constants {
    // presale
    uint constant PRESALE_START_TIME = 1621584000;
    uint constant PRESALE_END_TIME = 1622448000;
    uint256 constant PRESALE_EXCHANGE_RATE = 4000;      // 1 BNB ~ 4000 HUNNY
    uint256 constant PRESALE_MIN_AMOUNT = 2e17;         // 0.2 BNB
    uint256 constant PRESALE_MAX_AMOUNT = 4e18;         // 4 BNB (not whitelist only)
    uint256 constant PRESALE_PUBLIC_AMOUNT = 500e18;     // 500 BNB available for public address
    uint256 constant PRESALE_WHITELIST_AMOUNT = 750e18;  // 750 BNB available for whitelist address

    // pancake
    address constant PANCAKE_ROUTER = address(0x05fF2B0DB69458A0750badebc4f9e13aDd608C7F);
    address constant PANCAKE_FACTORY = address(0xBCfCcbde45cE874adCB698cC183deBcF17952812);
}


// Dependency file: contracts/interfaces/IPancakeRouter01.sol

// pragma solidity >=0.6.2;

interface IPancakeRouter01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
    external
    payable
    returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
    external
    returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
    external
    returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
    external
    payable
    returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}


// Dependency file: contracts/interfaces/IPancakeRouter02.sol


// pragma solidity >=0.6.2;

// import 'contracts/interfaces/IPancakeRouter01.sol';

interface IPancakeRouter02 is IPancakeRouter01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}


// Dependency file: contracts/interfaces/IPancakeFactory.sol

// pragma solidity ^0.6.12;

interface IPancakeFactory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}

// Root file: contracts/hunny/HunnyPresale.sol

pragma solidity ^0.6.12;

// import "@pancakeswap/pancake-swap-lib/contracts/math/SafeMath.sol";
// import "@pancakeswap/pancake-swap-lib/contracts/access/Ownable.sol";
// import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/IBEP20.sol";
// import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/SafeBEP20.sol";

// import "contracts/Constants.sol";
// import "contracts/interfaces/IPancakeRouter02.sol";
// import "contracts/interfaces/IPancakeFactory.sol";


interface IHunnyBNBPool {
    function depositTo(uint256 _pid, uint256 _amount, address _to) external;
}

interface IHunnyPool {
    function stakeTo(uint256 amount, address _to) external;
}

contract HunnyPresale is Ownable {
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;

    IPancakeFactory private factory = IPancakeFactory(Constants.PANCAKE_FACTORY);
    IPancakeRouter02 private router = IPancakeRouter02(Constants.PANCAKE_ROUTER);

    uint public startTime;
    uint public endTime;

    uint256 public exchangeRate;
    uint256 public minAmount;
    uint256 public maxAmount;
    uint256 public publicSaleTotal;
    uint256 public whitelistSaleTotal;

    address public token;

    address public masterChef;
    address public stakingRewards;

    uint public totalBalance;
    uint public totalFlipBalance;

    mapping (address => uint) private balance;
    mapping (address => bool) private whitelist;
    address[] public users;

    event Deposited(address indexed account, uint256 indexed amount);
    event Whitelisted(address indexed account, bool indexed allow);

    constructor() public {
        startTime = Constants.PRESALE_START_TIME;
        endTime = Constants.PRESALE_END_TIME;

        exchangeRate = Constants.PRESALE_EXCHANGE_RATE;

        minAmount = Constants.PRESALE_MIN_AMOUNT.mul(Constants.PRESALE_EXCHANGE_RATE);
        maxAmount = Constants.PRESALE_MAX_AMOUNT.mul(Constants.PRESALE_EXCHANGE_RATE);

        publicSaleTotal = Constants.PRESALE_PUBLIC_AMOUNT.mul(Constants.PRESALE_EXCHANGE_RATE);
        whitelistSaleTotal = Constants.PRESALE_WHITELIST_AMOUNT.mul(Constants.PRESALE_EXCHANGE_RATE);

        // add whitelist addresses
        configWhitelist(0xF628FA04Ae606530ef9EcAa79586b8d338Db94B8, true);
        configWhitelist(0x7fa889B83dE30a17Cd739588Ad765b5C1658fA33, true);
        configWhitelist(0x4C9343d92E9001fd4786E2A11029483a8f38D4AB, true);
        configWhitelist(0x6d9a8BfAC1bECE4b3B47730CC824a52812E34c3F, true);
        configWhitelist(0x34f3f50e9F576bD27b9EfC2d65c9DD74Db5a3d21, true);
        configWhitelist(0x6e7E602373404d4492e8D906557F07Bb6192a6Cd, true);
        configWhitelist(0xc85584eA7C9db6E1f5bdb536aF4F858eE4D56AC0, true);
        configWhitelist(0x3A6968224FeFcA80025994805F7cCcCE13480a5B, true);
        configWhitelist(0x3b6E6C9ff79CA9C5848229d95F6F110d2Bc2268d, true);
        configWhitelist(0x95D81FE1afCAE89de159142Fcb749b2FE2769F72, true);
        configWhitelist(0xdc50EB964e8D8BCACBCf86289d188Cb9dA29A2eF, true);
        configWhitelist(0x6BCd7D0B0b874b79592c356D51847d4852dEB10b, true);
        configWhitelist(0xEB382283eA0EaF1cFA91454C66160c1dcB26331b, true);
        configWhitelist(0x2f2bCA81b98c33ef5a65155fa0C6Df7d1e7D3D86, true);
        configWhitelist(0xcB17Aa0c15089027f756c913302693b28A825A97, true);
        configWhitelist(0x6eaBB6aa644a76765458b3a084820bBb65A0C778, true);
        configWhitelist(0x253eF98454d0C57E6C3E063b4d190E981b53E6a4, true);
        configWhitelist(0x77CAf519078Ca71Ac7E1F592A8C55f9D5460d50e, true);
        configWhitelist(0xD0e500c4fB2e03fae75C1C37cAe211C096c8e719, true);
    }

    receive() payable external {}

    function balanceOf(address account) public view returns(uint) {
        return balance[account];
    }

    function flipToken() public view returns(address) {
        return factory.getPair(token, router.WETH());
    }

    function usersLength() public view returns (uint256) {
        return users.length;
    }

    // return available amount for deposit in BNB
    function availableOf(address account) public view returns (uint256) {
        uint256 available;

        if (now < startTime || now > endTime) {
            return 0;
        }

        if (whitelist[account]) {
            available = whitelistSaleTotal;
        } else {
            available = maxAmount.sub(balance[account]);
            if (available > publicSaleTotal) {
                available = publicSaleTotal;
            }
        }

        return available.div(exchangeRate);
    }

    function deposit() public payable {
        address user = msg.sender;
        uint256 amount = msg.value.mul(exchangeRate); // convert BNB to HUNNY amount

        require(now >= startTime || now <= endTime, "!open");

        uint256 available = availableOf(user).mul(exchangeRate);
        require(amount <= available, "!available");
        require(amount >= minAmount, "!minimum");

        if (!findUser(user)) {
            users.push(user);
        }

        balance[user] = balance[user].add(amount);
        totalBalance = totalBalance.add(amount);

        if (whitelist[user]) {
            // whitelist
            whitelistSaleTotal = whitelistSaleTotal.sub(amount);
        } else {
            // public sale
            publicSaleTotal = publicSaleTotal.sub(amount);
        }

        emit Deposited(user, amount);
    }

    function findUser(address user) private view returns (bool) {
        for (uint i = 0; i < users.length; i++) {
            if (users[i] == user) {
                return true;
            }
        }

        return false;
    }

    // init and add liquidity
    function initialize(address _token, address _masterChef, address _rewards) public onlyOwner {
        token = _token;
        masterChef = _masterChef;
        stakingRewards = _rewards;

        require(IBEP20(token).balanceOf(address(this)) >= totalBalance, "less token");

        uint256 tokenAmount = totalBalance.div(2);
        uint256 amount = address(this).balance;

        IBEP20(token).safeApprove(address(router), 0);
        IBEP20(token).safeApprove(address(router), tokenAmount);
        router.addLiquidityETH{value: amount.div(2)}(token, tokenAmount, 0, 0, address(this), block.timestamp);

        address lp = flipToken();
        totalFlipBalance = IBEP20(lp).balanceOf(address(this));
    }

    function distributeTokens(uint256 _pid) public onlyOwner {
        address lpToken = flipToken();
        require(lpToken != address(0), 'not set flip');
        require(masterChef != address (0), 'not set masterChef');
        require(stakingRewards != address(0), 'not set stakingRewards');

        IBEP20(lpToken).safeApprove(masterChef, 0);
        IBEP20(lpToken).safeApprove(masterChef, totalFlipBalance);

        IBEP20(token).safeApprove(stakingRewards, 0);
        IBEP20(token).safeApprove(stakingRewards, totalBalance.div(2));

        for(uint i=0; i<usersLength(); i++) {
            address user = users[i];
            uint share = shareOf(user);

            _distributeFlip(user, share, _pid);
            _distributeToken(user, share);

            delete balance[user];
        }
    }

    function _distributeFlip(address user, uint share, uint pid) private {
        uint remaining = IBEP20(flipToken()).balanceOf(address(this));
        uint amount = totalFlipBalance.mul(share).div(1e18);
        if (amount == 0) return;

        if (remaining < amount) {
            amount = remaining;
        }
        IHunnyBNBPool(masterChef).depositTo(pid, amount, user);
    }

    function _distributeToken(address user, uint share) private {
        uint remaining = IBEP20(token).balanceOf(address(this));
        uint amount = totalBalance.div(2).mul(share).div(1e18);
        if (amount == 0) return;

        if (remaining < amount) {
            amount = remaining;
        }
        IHunnyPool(stakingRewards).stakeTo(amount, user);
    }


    function finalize() public onlyOwner {
        // will go to the HUNNY pool as reward
        payable(owner()).transfer(address(this).balance);

        // will burn unsold tokens
        uint tokenBalance = IBEP20(token).balanceOf(address(this));
        if (tokenBalance > 0) {
            IBEP20(token).transfer(owner(), tokenBalance);
        }
    }

    function shareOf(address _user) private view returns(uint256) {
        return balance[_user].mul(1e18).div(totalBalance);
    }

    function configWhitelist(address user, bool allow) public onlyOwner {
        whitelist[user] = allow;

        emit Whitelisted(user, allow);
    }

    // config the presale rate
    function configMoney(
        uint256 _exchangeRate,
        uint256 _minBNBAmount,
        uint256 _maxBNBAmount,
        uint256 _publicBNBTotal,
        uint256 _whitelistBNBTotal
    ) public onlyOwner {
        exchangeRate = _exchangeRate;

        minAmount = _minBNBAmount.mul(_exchangeRate);
        maxAmount = _maxBNBAmount.mul(_exchangeRate);

        publicSaleTotal = _publicBNBTotal.mul(_exchangeRate);
        whitelistSaleTotal = _whitelistBNBTotal.mul(_exchangeRate);
    }

    // config the presale timeline
    function configTime(
        uint _startTime,
        uint _endTime
    ) public onlyOwner {
        startTime = _startTime;
        endTime = _endTime;
    }

    // backup function for emergency situation
    function setAddress(address _token, address _masterChef, address _rewards) public onlyOwner {
        token = _token;
        masterChef = _masterChef;
        stakingRewards = _rewards;
    }
}
