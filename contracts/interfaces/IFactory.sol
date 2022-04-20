// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

interface IFactory {
    function createExchange(address token) external returns (address exchange);

    function getExchange(address token)
        external
        view
        returns (address exchange);

    function getToken(address exchange) external view returns (address token);

    function getTokenWithId(uint256 tokenId)
        external
        view
        returns (address token);
}
