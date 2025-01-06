// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import {Ownable} from '@hedy_chu/core-v3/contracts/dependencies/openzeppelin/contracts/Ownable.sol';
import {IERC20} from '@hedy_chu/core-v3/contracts/dependencies/openzeppelin/contracts/IERC20.sol';
import {GPv2SafeERC20} from '@hedy_chu/core-v3/contracts/dependencies/gnosis/contracts/GPv2SafeERC20.sol';
import {IWIP} from '@hedy_chu/core-v3/contracts/misc/interfaces/IWIP.sol';
import {IPool} from '@hedy_chu/core-v3/contracts/interfaces/IPool.sol';
import {IAToken} from '@hedy_chu/core-v3/contracts/interfaces/IAToken.sol';
import {ReserveConfiguration} from '@hedy_chu/core-v3/contracts/protocol/libraries/configuration/ReserveConfiguration.sol';
import {UserConfiguration} from '@hedy_chu/core-v3/contracts/protocol/libraries/configuration/UserConfiguration.sol';
import {DataTypes} from '@hedy_chu/core-v3/contracts/protocol/libraries/types/DataTypes.sol';
import {IWrappedTokenGatewayV3} from './interfaces/IWrappedTokenGatewayV3.sol';
import {DataTypesHelper} from '../libraries/DataTypesHelper.sol';

/**
 * @dev This contract is an upgrade of the WrappedTokenGatewayV3 contract, with immutable pool address.
 * This contract keeps the same interface of the deprecated WrappedTokenGatewayV3 contract.
 */
contract WrappedTokenGatewayV3 is IWrappedTokenGatewayV3, Ownable {
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
  using UserConfiguration for DataTypes.UserConfigurationMap;
  using GPv2SafeERC20 for IERC20;

  IWIP internal immutable WIP;
  IPool internal immutable POOL;

  /**
   * @dev Sets the WIP address and the PoolAddressesProvider address. Infinite approves pool.
   * @param wip Address of the Wrapped ip contract
   * @param owner Address of the owner of this contract
   **/
  constructor(address wip, address owner, IPool pool) {
    WIP = IWIP(wip);
    POOL = pool;
    transferOwnership(owner);
    IWIP(wip).approve(address(pool), type(uint256).max);
  }

  /**
   * @dev deposits WIP into the reserve, using native IP. A corresponding amount of the overlying asset (aTokens)
   * is minted.
   * @param onBehalfOf address of the user who will receive the aTokens representing the deposit
   * @param referralCode integrators are assigned a referral code and can potentially receive rewards.
   **/
  function depositIP(address, address onBehalfOf, uint16 referralCode) external payable override {
    WIP.deposit{value: msg.value}();
    POOL.deposit(address(WIP), msg.value, onBehalfOf, referralCode);
  }

  /**
   * @dev withdraws the WIP _reserves of msg.sender.
   * @param amount amount of aWIP to withdraw and receive native IP
   * @param to address of the user who will receive native IP
   */
  function withdrawIP(address, uint256 amount, address to) external override {
    IAToken aWIP = IAToken(POOL.getReserveData(address(WIP)).aTokenAddress);
    uint256 userBalance = aWIP.balanceOf(msg.sender);
    uint256 amountToWithdraw = amount;

    // if amount is equal to uint(-1), the user wants to redeem everything
    if (amount == type(uint256).max) {
      amountToWithdraw = userBalance;
    }
    aWIP.transferFrom(msg.sender, address(this), amountToWithdraw);
    POOL.withdraw(address(WIP), amountToWithdraw, address(this));
    WIP.withdraw(amountToWithdraw);
    _safeTransferIP(to, amountToWithdraw);
  }

  /**
   * @dev repays a borrow on the WIP reserve, for the specified amount (or for the whole amount, if uint256(-1) is specified).
   * @param amount the amount to repay, or uint256(-1) if the user wants to repay everything
   * @param rateMode the rate mode to repay
   * @param onBehalfOf the address for which msg.sender is repaying
   */
  function repayIP(
    address,
    uint256 amount,
    uint256 rateMode,
    address onBehalfOf
  ) external payable override {
    (uint256 stableDebt, uint256 variableDebt) = DataTypesHelper.getUserCurrentDebt(
      onBehalfOf,
      POOL.getReserveData(address(WIP))
    );

    uint256 paybackAmount = DataTypes.InterestRateMode(rateMode) ==
      DataTypes.InterestRateMode.STABLE
      ? stableDebt
      : variableDebt;

    if (amount < paybackAmount) {
      paybackAmount = amount;
    }
    require(msg.value >= paybackAmount, 'msg.value is less than repayment amount');
    WIP.deposit{value: paybackAmount}();
    POOL.repay(address(WIP), msg.value, rateMode, onBehalfOf);

    // refund remaining dust IP
    if (msg.value > paybackAmount) _safeTransferIP(msg.sender, msg.value - paybackAmount);
  }

  /**
   * @dev borrow WIP, unwraps to IP and send both the IP and DebtTokens to msg.sender, via `approveDelegation` and onBehalf argument in `Pool.borrow`.
   * @param amount the amount of IP to borrow
   * @param interestRateMode the interest rate mode
   * @param referralCode integrators are assigned a referral code and can potentially receive rewards
   */
  function borrowIP(
    address,
    uint256 amount,
    uint256 interestRateMode,
    uint16 referralCode
  ) external override {
    POOL.borrow(address(WIP), amount, interestRateMode, referralCode, msg.sender);
    WIP.withdraw(amount);
    _safeTransferIP(msg.sender, amount);
  }

  /**
   * @dev withdraws the WIP _reserves of msg.sender.
   * @param amount amount of aWIP to withdraw and receive native IP
   * @param to address of the user who will receive native IP
   * @param deadline validity deadline of permit and so depositWithPermit signature
   * @param permitV V parameter of ERC712 permit sig
   * @param permitR R parameter of ERC712 permit sig
   * @param permitS S parameter of ERC712 permit sig
   */
  function withdrawIPWithPermit(
    address,
    uint256 amount,
    address to,
    uint256 deadline,
    uint8 permitV,
    bytes32 permitR,
    bytes32 permitS
  ) external override {
    IAToken aWIP = IAToken(POOL.getReserveData(address(WIP)).aTokenAddress);
    uint256 userBalance = aWIP.balanceOf(msg.sender);
    uint256 amountToWithdraw = amount;

    // if amount is equal to type(uint256).max, the user wants to redeem everything
    if (amount == type(uint256).max) {
      amountToWithdraw = userBalance;
    }
    // permit `amount` rather than `amountToWithdraw` to make it easier for front-ends and integrators
    aWIP.permit(msg.sender, address(this), amount, deadline, permitV, permitR, permitS);
    aWIP.transferFrom(msg.sender, address(this), amountToWithdraw);
    POOL.withdraw(address(WIP), amountToWithdraw, address(this));
    WIP.withdraw(amountToWithdraw);
    _safeTransferIP(to, amountToWithdraw);
  }

  /**
   * @dev transfer IP to an address, revert if it fails.
   * @param to recipient of the transfer
   * @param value the amount to send
   */
  function _safeTransferIP(address to, uint256 value) internal {
    (bool success, ) = to.call{value: value}(new bytes(0));
    require(success, 'IP_TRANSFER_FAILED');
  }

  /**
   * @dev transfer ERC20 from the utility contract, for ERC20 recovery in case of stuck tokens due
   * direct transfers to the contract address.
   * @param token token to transfer
   * @param to recipient of the transfer
   * @param amount amount to send
   */
  function emergencyTokenTransfer(address token, address to, uint256 amount) external onlyOwner {
    IERC20(token).safeTransfer(to, amount);
  }

  /**
   * @dev transfer native IP from the utility contract, for native IP recovery in case of stuck IP
   * due to selfdestructs or IP transfers to the pre-computed contract address before deployment.
   * @param to recipient of the transfer
   * @param amount amount to send
   */
  function emergencyIPerTransfer(address to, uint256 amount) external onlyOwner {
    _safeTransferIP(to, amount);
  }

  /**
   * @dev Get WIP address used by WrappedTokenGatewayV3
   */
  function getWIPAddress() external view returns (address) {
    return address(WIP);
  }

  /**
   * @dev Only WIP contract is allowed to transfer IP here. Prevent other addresses to send IPer to this contract.
   */
  receive() external payable {
    require(msg.sender == address(WIP), 'Receive not allowed');
  }

  /**
   * @dev Revert fallback calls
   */
  fallback() external payable {
    revert('Fallback not allowed');
  }
}
