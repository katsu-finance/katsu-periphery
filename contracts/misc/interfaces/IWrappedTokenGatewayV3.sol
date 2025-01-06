// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

interface IWrappedTokenGatewayV3 {
  function depositIP(address pool, address onBehalfOf, uint16 referralCode) external payable;

  function withdrawIP(address pool, uint256 amount, address onBehalfOf) external;

  function repayIP(
    address pool,
    uint256 amount,
    uint256 rateMode,
    address onBehalfOf
  ) external payable;

  function borrowIP(
    address pool,
    uint256 amount,
    uint256 interestRateMode,
    uint16 referralCode
  ) external;

  function withdrawIPWithPermit(
    address pool,
    uint256 amount,
    address to,
    uint256 deadline,
    uint8 permitV,
    bytes32 permitR,
    bytes32 permitS
  ) external;
}
