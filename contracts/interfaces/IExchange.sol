// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

interface IExchange {
    function setup(address tokenAddr) external;

    function addLiquidity(
        uint256 minLiquidity,
        uint256 maxTokens,
        uint256 deadline
    ) external payable returns (uint256);

    function removeLiquidity(
        uint256 amount,
        uint256 minEth,
        uint256 minTokens,
        uint256 deadline
    ) external returns (uint256, uint256);

    function ethToTokenSwapInput(uint256 minTokens, uint256 deadline)
        external
        payable
        returns (uint256);

    function ethToTokenTransferInput(
        uint256 minTokens,
        uint256 deadline,
        address recipient
    ) external payable returns (uint256);

    function ethToTokenSwapOutput(uint256 tokensBought, uint256 deadline)
        external
        payable
        returns (uint256);

    function ethToTokenTransferOutput(
        uint256 tokensBought,
        uint256 deadline,
        address recipient
    ) external payable returns (uint256);

    function tokenToEthSwapInput(
        uint256 tokensSold,
        uint256 minEth,
        uint256 deadline
    ) external returns (uint256);

    function tokenToEthTransferInput(
        uint256 tokensSold,
        uint256 minEth,
        uint256 deadline,
        address recipient
    ) external returns (uint256);

    function tokenToEthSwapOutput(
        uint256 ethBought,
        uint256 maxTokens,
        uint256 deadline
    ) external returns (uint256);

    function tokenToEthTransferOutput(
        uint256 eth_bought,
        uint256 max_tokens,
        uint256 deadline,
        address recipient
    ) external returns (uint256);

    function tokenToTokenSwapInput(
        uint256 tokensSold,
        uint256 minTokensBought,
        uint256 minEthBought,
        uint256 deadline,
        address tokenAddr
    ) external returns (uint256);

    function tokenToTokenTransferInput(
        uint256 tokenSold,
        uint256 minTokensBought,
        uint256 min_eth_bought,
        uint256 deadline,
        address recipient,
        address tokenAddr
    ) external returns (uint256);

    function tokenToTokenSwapOutput(
        uint256 tokensBought,
        uint256 maxTokensSold,
        uint256 maxEthSold,
        uint256 deadline,
        address tokenAddr
    ) external returns (uint256);

    function tokenToTokenTransferOutput(
        uint256 tokens_bought,
        uint256 max_tokens_sold,
        uint256 max_eth_sold,
        uint256 deadline,
        address recipient,
        uint256 token_addr
    ) external returns (uint256);

    function tokenToExchangeSwapInput(
        uint256 tokensSold,
        uint256 minTokensBought,
        uint256 minEthBought,
        uint256 deadline,
        address exchangeAddr
    ) external returns (uint256);

    function tokenToExchangeTransferInput(
        uint256 tokensSold,
        uint256 minTokensBought,
        uint256 minEthBought,
        uint256 deadline,
        address recipient,
        address exchangeAddr
    ) external returns (uint256);

    function tokenToExchangeSwapOutput(
        uint256 tokensBought,
        uint256 maxTokensSold,
        uint256 maxEthSold,
        uint256 deadline,
        address exchangeAddr
    ) external returns (uint256);

    function tokenToExchangeTransferOutput(
        uint256 tokensBought,
        uint256 maxTokensSold,
        uint256 maxEthSold,
        uint256 deadline,
        address recipient,
        address exchangeAddr
    ) external returns (uint256);

    function getEthToTokenInputPrice(uint256 ethSold)
        external
        view
        returns (uint256);

    function getEthToTokenOutputPrice(uint256 tokensBought)
        external
        view
        returns (uint256);

    function getTokenToEthInputPrice(uint256 tokensSold)
        external
        view
        returns (uint256);

    function getTokenToEthOutputPrice(uint256 ethBought)
        external
        view
        returns (uint256);

    function tokenAddress() external view returns (address);

    function factoryAddress() external view returns (address);
}
