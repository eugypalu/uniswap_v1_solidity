// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import './interfaces/IExchange.sol';
import './interfaces/IFactory.sol';

contract Exchange {
    
    using SafeMath for uint256;

    event TokenPurchase(
        address indexed buyer,
        uint256 indexed ethSold,
        uint256 indexed tokensBought
    );

    event EthPurchase(
        address indexed buyer,
        uint256 indexed tokensSold,
        uint256 indexed ethBought
    );

    event AddLiquidity(
        address indexed provider,
        uint256 indexed ethAmount,
        uint256 indexed tokenAmount
    );

    event RemoveLiquidity(
        address indexed provider,
        uint256 indexed ethAmount,
        uint256 indexed tokenAmount
    );

    bytes32 public name;
    bytes32 public symbol;
    uint256 public decimals;
    uint256 public totalSupply;
    address public token;
    address public factory;

    /**
     * @dev This function acts as a contract constructor. It is called once by the factory during contract creation.
     */
    function setup(address tokenAddr) external {
        require(
            factory == address(0) && token == address(0),
            "exchange:setup factory and token already set"
        );
        factory = msg.sender;
        token = tokenAddr;
        name = "UNI-V1";
        symbol = "UNIV1";
        decimals = 18;
    }

    /**
     * @notice Deposit ETH and Tokens  at current ratio to mint UNI tokens.
     * @dev minLiquidity does nothing when total UNI supply is 0.
     * @param minLiquidity Minimum number of UNI sender will mint if total UNI supply is greater than 0.
     * @param maxTokens Maximum number of tokens deposited. Deposits max amount if total UNI supply is 0.
     * @param deadline Time after which this transaction can no longer be executed.
     * @return amount minted. 
     */
    function addLiquidity(uint256 minLiquidity, uint256 maxTokens, uint256 deadline) external payable returns(uint256) {
        require(deadline > block.number && maxTokens > 0 && msg.value > 0, "exchange:addLiquidity invalid parameters");
        uint256 totalLiquidity = totalSupply;
        if(totalLiquidity > 0) {
            require(minLiquidity > 0, "exchange:addLiquidity minLiquidity must be greater than 0");
            uint256 ethReserve = address(this).balance.sub(msg.value);
            uint256 tokenReserve = IERC20(token).balanceOf(address(this));
            uint256 tokenAmount = msg.value.mul(tokenReserve).div(ethReserve).add(1);
            uint256 liquidityMinted = msg.value.mul(totalLiquidity).div(ethReserve);
            require(maxTokens >= tokenAmount && liquidityMinted >= minLiquidity, "exchange:addLiquidity maxTokens or liquidityMinted is too low");
            totalSupply = totalLiquidity.add(liquidityMinted);
            require(IERC20(token).transferFrom(msg.sender, address(this), tokenAmount), "exchange:addLiquidity failed to transfer tokens");
            emit AddLiquidity(msg.sender, msg.value, tokenAmount);
            return liquidityMinted;
        } else {
            require(
                factory != address(0) && token != address(0) && msg.value >= 1000000000,
                "exchange:addLiquidity factory and token not yet set and wrong msg.value"
            );
            uint256 tokenAmount = maxTokens;
            uint256 initialLiquidity = address(this).balance;
            totalSupply = initialLiquidity;
            require(IERC20(token).transferFrom(msg.sender, address(this), tokenAmount), "exchange:addLiquidity failed to transfer tokens");
            emit AddLiquidity(msg.sender, msg.value, tokenAmount);
            return initialLiquidity;
        }
    }

    /**
     * @dev Burn UNI tokens to withdraw ETH and Tokens at current ratio.
     * @param amount Amount of UNI burned.
     * @param minEth Minimum ETH withdrawn.
     * @param minTokens Minimum Tokens withdrawn.
     * @param deadline Time after which this transaction can no longer be executed.
     * @return The amount of ETH and Tokens withdrawn.
     */
    function removeLiquidity(uint256 amount, uint256 minEth, uint256 minTokens, uint256 deadline) external returns(uint256, uint256) {
        require(amount > 0 && deadline > block.number && minEth > 0 && minTokens > 0, "exchange:removeLiquidity invalid parameters");
        uint256 totalLiquidity = totalSupply;
        require(totalLiquidity > 0, "exchange:removeLiquidity totalLiquidity must be greater than 0");
        uint256 tokenReserve = IERC20(token).balanceOf(address(this));
        uint256 ethAmount = amount.mul(address(this).balance).div(totalLiquidity);
        uint256 tokenAmount = amount.mul(tokenReserve).div(totalLiquidity);
        require(ethAmount >= minEth && tokenAmount >= minTokens, "exchange:removeLiquidity minEth or minTokens amount too low");
        totalSupply = totalLiquidity.sub(amount);
        (bool success, ) = msg.sender.call{value: ethAmount}("");
        require(success, "exchange:removeLiquidity failed to send eth");
        require(IERC20(token).transfer(msg.sender, tokenAmount), "exchange:removeLiquidity failed to transfer tokens");
        emit RemoveLiquidity(msg.sender, ethAmount, tokenAmount);
        return (ethAmount, tokenAmount);
    }

    /**
     * @dev Pricing function for converting between ETH and Tokens.
     * @param inputAmount Amount of ETH or Tokens being sold.
     * @param inputReserve Amount of ETH or Tokens (input type) in exchange reserves.
     * @param outputReserve Amount of ETH or Tokens (output type) in exchange reserves.
     * @return Amount of ETH or Tokens bought.
     */
    function getInputPrice(uint256 inputAmount, uint256 inputReserve, uint256 outputReserve) private pure returns(uint256) {
        require(inputReserve > 0 && outputReserve > 0, "exchange:getInputPrice invalid parameters");
        uint256 inputAmountWithFee = inputAmount.mul(997);
        uint256 numerator = inputAmountWithFee.mul(outputReserve);
        uint256 denominator = inputReserve.mul(1000).add(inputAmountWithFee);
        return numerator.div(denominator);
    }

    /**
     * @dev Pricing function for converting between ETH and Tokens.
     * @param outputAmount Amount of ETH or Tokens being bought.
     * @param inputReserve Amount of ETH or Tokens (input type) in exchange reserves.
     * @param outputReserve Amount of ETH or Tokens (output type) in exchange reserves.
     * @return Amount of ETH or Tokens sold.
     */
    function getOutputPrice(uint256 outputAmount, uint256 inputReserve, uint256 outputReserve) private pure returns(uint256) {
        require(inputReserve > 0 && outputReserve > 0, "exchange:getOutputPrice invalid parameters");
        uint256 numerator = inputReserve.mul(outputAmount).mul(1000);
        uint256 denominator = (outputReserve.sub(outputAmount)).mul(997);
        return numerator.div(denominator).add(1);
    }

    function ethToTokenInput(uint256 ethSold, uint256 minTokens, uint256 deadline, address buyer, address recipient) private returns(uint256) {
        require(deadline >= block.number && ethSold > 0 && minTokens > 0, "exchange:ethToTokenInput invalid parameters");
        uint256 tokenReserve = IERC20(token).balanceOf(address(this));
        uint256 tokensBought = getInputPrice(ethSold, address(this).balance.sub(ethSold), tokenReserve);
        require(tokensBought >= minTokens, "exchange:ethToTokenInput failed to buy this amount of tokens");
        require(IERC20(token).transfer(recipient, tokensBought), "exchange:ethToTokenInput failed to transfer tokens");
        emit TokenPurchase(buyer, ethSold, tokensBought);
        return tokensBought;
    }

    /**
     * @notice Convert ETH to Tokens.
     * @dev User specifies exact input (msg.value) and minimum output.
     * @param minTokens Minimum Tokens bought.
     * @param deadline Time after which this transaction can no longer be executed.
     * @return Amount of Tokens bought.
     */
    function ethToTokenSwapInput(uint256 minTokens, uint256 deadline) external payable returns(uint256) {
        return ethToTokenInput(msg.value, minTokens, deadline, msg.sender, msg.sender);
    }

    /**
     * @notice Convert ETH to Tokens and transfers Tokens to recipient.
     * @dev User specifies exact input (msg.value) and minimum output
     * @param minTokens Minimum Tokens bought.
     * @param deadline Time after which this transaction can no longer be executed.
     * @param recipient The address that receives output Tokens.
     * @return Amount of Tokens bought.
     */
    function ethToTokenTransferInput(uint256 minTokens, uint256 deadline, address recipient) external payable returns(uint256) {
        require(recipient != address(0) && recipient != address(this), "exchange:ethToTokenTransferInput invalid recipient address");
        return ethToTokenInput(msg.value, minTokens, deadline, msg.sender, recipient);
    }

    function ethToTokenOutput(uint256 tokensBought, uint256 maxEth, uint256 deadline, address buyer, address recipient) private returns(uint256) {
        require(deadline >= block.number && tokensBought > 0 && maxEth > 0, "exchange:ethToTokenOutput invalid parameters");
        uint256 tokenReserve = IERC20(token).balanceOf(address(this));
        uint256 ethSold = getOutputPrice(tokensBought, address(this).balance.sub(maxEth), tokenReserve);
        uint256 ethRefund = maxEth.sub(ethSold);
        if(ethRefund > 0) {
            (bool success, ) = msg.sender.call{value: ethRefund}("");
            require(success, "exchange:ethToTokenOutput failed to send eth");
        }
        require(IERC20(token).transfer(recipient, tokensBought), "exchange:ethToTokenOutput failed to transfer tokens");
        emit TokenPurchase(buyer, ethSold, tokensBought);
        return ethSold;
    }

    /**
     * @notice Convert ETH to Tokens.
     * @dev User specifies maximum input (msg.value) and exact output.
     * @param tokensBought Amount of tokens bought.
     * @param deadline Time after which this transaction can no longer be executed.
     * @return Amount of ETH sold.
     */
    function ethToTokenSwapOutput(uint256 tokensBought, uint256 deadline) external payable returns(uint256) {
        return ethToTokenOutput(tokensBought, msg.value, deadline, msg.sender, msg.sender);
    }

    /**
     * @notice Convert ETH to Tokens and transfers Tokens to recipient.
     * @dev User specifies maximum input (msg.value) and exact output.
     * @param tokensBought Amount of tokens bought.
     * @param deadline Time after which this transaction can no longer be executed.
     * @param recipient The address that receives output Tokens.
     * @return Amount of ETH sold.
     */
    function ethToTokenTransferOutput(uint256 tokensBought, uint256 deadline, address recipient) external payable returns(uint256) {
        require(recipient != address(0) && recipient != address(this), "exchange:ethToTokenTransferOutput invalid recipient address");
        return ethToTokenOutput(tokensBought, msg.value, deadline, msg.sender, recipient);
    }

    function tokenToEthInput(uint256 tokensSold, uint256 minEth, uint256 deadline, address buyer, address recipient) private returns(uint256) {
        require(deadline >= block.number && tokensSold > 0 && minEth > 0, "exchange:tokenToEthInput invalid parameters");
        uint256 tokenReserve = IERC20(token).balanceOf(address(this));
        uint256 ethBought = getInputPrice(tokensSold, tokenReserve, address(this).balance);
        require(ethBought >= minEth, "exchange:tokenToEthInput too low amount");
        (bool success, ) = recipient.call{value: ethBought}("");
        require(success, "exchange:tokenToEthInput failed to send eth");
        require(IERC20(token).transferFrom(buyer, address(this), tokensSold), "exchange:tokenToEthInput failed to transfer tokens");
        emit EthPurchase(buyer, tokensSold, ethBought);
        return ethBought;
    }

    /**
     * @notice Convert Tokens to ETH.
     * @dev User specifies exact input and minimum output.
     * @param tokensSold Amount of Tokens sold.
     * @param minEth Minimum ETH purchased.
     * @param deadline Time after which this transaction can no longer be executed.
     * @return Amount of ETH bought.
     */
    function tokenToEthSwapInput(uint256 tokensSold, uint256 minEth, uint256 deadline) external returns(uint256) {
        return tokenToEthInput(tokensSold, minEth, deadline, msg.sender, msg.sender);
    }

    /**
     * @notice Convert Tokens to ETH and transfers ETH to recipient.
     * @dev User specifies exact input and minimum output.
     * @param tokensSold Amount of Tokens sold.
     * @param minEth Minimum ETH purchased.
     * @param deadline Time after which this transaction can no longer be executed.
     * @param recipient The address that receives output ETH.
     * @return Amount of ETH bought.
     */
    function tokenToEthTransferInput(uint256 tokensSold, uint256 minEth, uint256 deadline, address recipient) external returns(uint256) {
        require(recipient != address(0) && recipient != address(this), "exchange:tokenToEthTransferInput invalid recipient address");
        return tokenToEthInput(tokensSold, minEth, deadline, msg.sender, recipient);
    }

    function tokenToEthOutput(uint256 ethBought, uint256 maxTokens, uint256 deadline, address buyer, address recipient) private returns(uint256) {
        require(deadline >= block.number && ethBought > 0, "exchange:tokenToEthOutput invalid parameters");
        uint256 tokenReserve = IERC20(token).balanceOf(address(this));
        uint256 tokenSold = getOutputPrice(ethBought, tokenReserve, address(this).balance);
        require(maxTokens >= tokenSold, "exchange:tokenToEthOutput too high amount");
        (bool success, ) = recipient.call{value: ethBought}("");
        require(success, "exchange:tokenToEthOutput failed to send eth");
        require(IERC20(token).transferFrom(buyer, address(this), tokenSold), "exchange:tokenToEthOutput failed to transfer tokens");
        emit EthPurchase(buyer, tokenSold, ethBought);
        return tokenSold;
    }

    /**
     * @notice Convert Tokens to ETH.
     * @dev User specifies maximum input and exact output.
     * @param ethBought Amount of ETH purchased.
     * @param maxTokens Maximum Tokens sold.
     * @param deadline Time after which this transaction can no longer be executed.
     * @return Amount of Tokens sold.
     */
    function tokenToEthSwapOutput(uint256 ethBought, uint256 maxTokens, uint256 deadline) external returns(uint256) {
        return tokenToEthOutput(ethBought, maxTokens, deadline, msg.sender, msg.sender);
    }

    /**
     * @notice Convert Tokens to ETH and transfers ETH to recipient.
     * @dev User specifies maximum input and exact output.
     * @param ethBought Amount of ETH purchased.
     * @param maxTokens Maximum Tokens sold.
     * @param deadline Time after which this transaction can no longer be executed.
     * @param recipient The address that receives output ETH.
     * @return Amount of Tokens sold.
     */
    function tokenToEthTransferOutput(uint256 ethBought, uint256 maxTokens, uint256 deadline, address recipient) external returns(uint256) {
        require(recipient != address(0) && recipient != address(this), "exchange:tokenToEthTransferOutput invalid recipient address");
        return tokenToEthOutput(ethBought, maxTokens, deadline, msg.sender, recipient);
    }

    function tokenToTokenInput(uint256 tokensSold, uint256 minTokensBought, uint256 minEthBought, uint256 deadline, address buyer, address recipient, address exchangeAddr) private returns(uint256) {
        require(deadline >= block.number && tokensSold> 0 && minTokensBought > 0 && minEthBought > 0, "exchange:tokenToTokenInput invalid parameters");
        require(exchangeAddr != address(this) && exchangeAddr != address(0), "exchange:tokenToTokenInput invalid exchange address");
        uint256 tokenReserve = IERC20(token).balanceOf(address(this));
        uint256 ethBought = getInputPrice(tokensSold, tokenReserve, address(this).balance);
        require(ethBought >= minEthBought, "exchange:tokenToTokenInput too low amount");
        require(IERC20(token).transferFrom(buyer, address(this), tokensSold), "exchange:tokenToTokenInput failed to transfer tokens");
        uint256 tokensBought = IExchange(exchangeAddr).ethToTokenTransferInput{value: ethBought}(minTokensBought, deadline, recipient);
        emit EthPurchase(buyer, tokensSold, ethBought);
        return tokensBought;
    }

    /**
     * @notice Convert Tokens  to Tokens (tokenAddr).
     * @dev User specifies exact input and minimum output.
     * @param tokensSold Amount of Tokens sold.
     * @param minTokensBought Minimum Tokens (tokenAddr) purchased.
     * @param minEthBought Minimum ETH purchased as intermediary.
     * @param deadline Time after which this transaction can no longer be executed.
     * @param tokenAddr The address of the token being purchased.
     * @return Amount of Tokens (tokenAddr) bought.
     */
    function tokenToTokenSwapInput(uint256 tokensSold, uint256 minTokensBought, uint256 minEthBought, uint256 deadline, address tokenAddr) external returns(uint256) {
        address exchangeAddr = IFactory(factory).getExchange(tokenAddr);
        return tokenToTokenInput(tokensSold, minTokensBought, minEthBought, deadline, msg.sender, msg.sender, exchangeAddr);
    }

    /**
     * @notice Convert Tokens  to Tokens (tokenAddr) and transfers
     *         Tokens (tokenAddr) to recipient.
     * @dev User specifies exact input and minimum output.
     * @param tokenSold Amount of Tokens sold.
     * @param minTokensBought Minimum Tokens (tokenAddr) purchased.
     * @param minEthBought Minimum ETH purchased as intermediary.
     * @param deadline Time after which this transaction can no longer be executed.
     * @param recipient The address that receives output ETH.
     * @param tokenAddr The address of the token being purchased.
     * @return Amount of Tokens (tokenAddr) bought.
     */
    function tokenToTokenTransferInput(uint256 tokenSold, uint256 minTokensBought, uint256 minEthBought, uint256 deadline, address recipient, address tokenAddr) external returns(uint256) {
        address exchangeAddr = IFactory(factory).getExchange(tokenAddr);
        return tokenToTokenInput(tokenSold, minTokensBought, minEthBought, deadline, msg.sender, recipient, exchangeAddr);
    }

    function tokenToTokenOutput(uint256 tokensBought, uint256 maxTokensSold, uint256 maxEthSold, uint256 deadline, address buyer, address recipient, address exchangeAddr) private returns(uint256) {
        require(deadline >= block.number && tokensBought > 0 && maxEthSold > 0, "exchange:tokenToTokenOutput invalid parameters");
        require(exchangeAddr != address(this) && exchangeAddr != address(0), "exchange:tokenToTokenOutput invalid exchange address");
        uint256 ethBought = IExchange(exchangeAddr).getEthToTokenOutputPrice(tokensBought);
        uint256 tokenReserve = IERC20(token).balanceOf(address(this));
        uint256 tokensSold = getOutputPrice(ethBought, tokenReserve, address(this).balance);
        require(maxTokensSold >= tokensSold && maxEthSold >= ethBought, "exchange:tokenToTokenOutput too high amount");
        require(IERC20(token).transferFrom(buyer, address(this), tokensSold), "exchange:tokenToTokenOutput failed to transfer tokens");
        IExchange(exchangeAddr).ethToTokenTransferOutput{value: ethBought}(tokensBought, deadline, recipient);
        emit EthPurchase(buyer, tokensSold, ethBought);
        return tokensSold;
    }

    /**
     * @notice Convert Tokens  to Tokens (tokenAddr).
     * @dev User specifies maximum input and exact output.
     * @param tokensBought Amount of Tokens (tokenAddr) bought.
     * @param maxTokensSold Maximum Tokens  sold.
     * @param maxEthSold Maximum ETH purchased as intermediary.
     * @param deadline Time after which this transaction can no longer be executed.
     * @param tokenAddr The address of the token being purchased.
     * @return Amount of Tokens  sold.
     */
    function tokenToTokenSwapOutput(uint256 tokensBought, uint256 maxTokensSold, uint256 maxEthSold, uint256 deadline, address tokenAddr) external returns(uint256) {
        address exchangeAddr = IFactory(factory).getExchange(tokenAddr);
        return tokenToTokenOutput(tokensBought, maxTokensSold, maxEthSold, deadline, msg.sender, msg.sender, exchangeAddr);
    }

    /**
     * @notice Convert Tokens  to Tokens (tokenAddr) and transfers
     *         Tokens (tokenAddr) to recipient.
     * @dev User specifies maximum input and exact output.
     * @param tokensBought Amount of Tokens (tokenAddr) bought.
     * @param maxTokensSold Maximum Tokens  sold.
     * @param maxEthSold Maximum ETH purchased as intermediary.
     * @param deadline Time after which this transaction can no longer be executed.
     * @param recipient The address that receives output ETH.
     * @param tokenAddr The address of the token being purchased.
     * @return Amount of Tokens  sold.
     */
    function tokenToTokenTransferOutput(uint256 tokensBought, uint256 maxTokensSold, uint256 maxEthSold, uint256 deadline, address recipient, address tokenAddr) external returns(uint256) {
        address exchangeAddr = IFactory(factory).getExchange(tokenAddr);
        return tokenToTokenOutput(tokensBought, maxTokensSold, maxEthSold, deadline, msg.sender, recipient, exchangeAddr);
    }

    /**
     * @notice Convert Tokens  to Tokens (exchangeAddr.token).
     * @dev Allows trades through contracts that were not deployed from the same factory.
     * @dev User specifies exact input and minimum output.
     * @param tokensSold Amount of Tokens sold.
     * @param minTokensBought Minimum Tokens (tokenAddr) purchased.
     * @param deadline Time after which this transaction can no longer be executed.
     * @param exchangeAddr The address of the exchange for the token being purchased.
     * @return Amount of Tokens (exchangeAddr.token) bought.
     */
    function tokenToExchangeSwapInput(uint256 tokensSold, uint256 minTokensBought, uint256 deadline, address exchangeAddr) external returns(uint256) {
        return tokenToTokenInput(tokensSold, minTokensBought, minTokensBought, deadline, msg.sender, msg.sender, exchangeAddr);
    }

    /**
     * @notice Convert Tokens  to Tokens (exchangeAddr.token) and transfers
     *         Tokens (exchangeAddr.token) to recipient.
     * @dev Allows trades through contracts that were not deployed from the same factory.
     * @dev User specifies exact input and minimum output.
     * @param tokensSold Amount of Tokens sold.
     * @param minTokensBought Minimum Tokens (tokenAddr) purchased.
     * @param minEthBought Minimum ETH purchased as intermediary.
     * @param deadline Time after which this transaction can no longer be executed.
     * @param recipient The address that receives output ETH.
     * @param exchangeAddr The address of the exchange for the token being purchased.
     * @return Amount of Tokens (exchangeAddr.token) bought.
     */
    function tokenToExchangeTransferInput(uint256 tokensSold, uint256 minTokensBought, uint256 minEthBought, uint256 deadline, address recipient, address exchangeAddr) external returns(uint256) {
        require(recipient != address(this), "exchange:tokenToExchangeTransferInput invalid recipient address");
        return tokenToTokenInput(tokensSold, minTokensBought, minEthBought, deadline, msg.sender, recipient, exchangeAddr);
    }

    /**
     * @notice Convert Tokens  to Tokens (exchangeAddr.token).
     * @dev Allows trades through contracts that were not deployed from the same factory.
     * @dev User specifies maximum input and exact output.
     * @param tokensBought Amount of Tokens (tokenAddr) bought.
     * @param maxTokensSold Maximum Tokens  sold.
     * @param maxEthSold Maximum ETH purchased as intermediary.
     * @param deadline Time after which this transaction can no longer be executed.
     * @param exchangeAddr The address of the exchange for the token being purchased.
     * @return Amount of Tokens  sold.
     */
    function tokenToExchangeSwapOutput(uint256 tokensBought, uint256 maxTokensSold, uint256 maxEthSold, uint256 deadline, address exchangeAddr) external returns(uint256){
        return tokenToTokenOutput(tokensBought, maxTokensSold, maxEthSold, deadline, msg.sender, msg.sender, exchangeAddr);
    }

    /**
     * @notice Convert Tokens  to Tokens (exchangeAddr.token) and transfers
     *         Tokens (exchangeAddr.token) to recipient.
     * @dev Allows trades through contracts that were not deployed from the same factory.
     * @dev User specifies maximum input and exact output.
     * @param tokensBought Amount of Tokens (tokenAddr) bought.
     * @param maxTokensSold Maximum Tokens  sold.
     * @param maxEthSold Maximum ETH purchased as intermediary.
     * @param deadline Time after which this transaction can no longer be executed.
     * @param recipient The address that receives output ETH.
     * @return Amount of Tokens  sold.
     */
    function tokenToExchangeTransferOutput(uint256 tokensBought, uint256 maxTokensSold, uint256 maxEthSold, uint256 deadline, address recipient, address exchangeAddr) external returns(uint256) {
        require(recipient != address(this), "exchange:tokenToExchangeTransferOutput invalid recipient address");
        return tokenToTokenOutput(tokensBought, maxTokensSold, maxEthSold, deadline, msg.sender, recipient, exchangeAddr);
    }

    /**
     * @notice Public price function for ETH to Token trades with an exact input.
     * @param ethSold Amount of ETH sold.
     * @return Amount of Tokens that can be bought with input ETH.
     */
    function getEthToTokenInputPrice(uint256 ethSold) external view returns(uint256) {
        require(ethSold > 0, "exchange:getEthToTokenInputPrice invalid parameters");
        uint256 tokenReserve = IERC20(token).balanceOf(address(this));
        return getInputPrice(ethSold, address(this).balance, tokenReserve);
    }

    /**
     * @notice Public price function for ETH to Token trades with an exact output.
     * @param tokensBought Amount of Tokens bought.
     * @return Amount of ETH needed to buy output Tokens.
     */
    function getEthToTokenOutputPrice(uint256 tokensBought) external view returns(uint256) {
        require(tokensBought > 0, "exchange:getEthToTokenOutputPrice invalid parameters");
        uint256 tokenReserve = IERC20(token).balanceOf(address(this));
        uint256 ethSold = getOutputPrice(tokensBought, address(this).balance, tokenReserve);
        return ethSold;
    }

    /**
     * @notice Public price function for Token to ETH trades with an exact input.
     * @param tokensSold Amount of Tokens sold.
     * @return Amount of ETH that can be bought with input Tokens.
     */
    function getTokenToEthInputPrice(uint256 tokensSold) external view returns(uint256){
        require(tokensSold > 0, "exchange:getTokenToEthInputPrice invalid parameters");
        uint256 tokenReserve = IERC20(token).balanceOf(address(this));
        uint256 ethBought = getInputPrice(tokensSold, tokenReserve, address(this).balance);
        return ethBought;
    }

    /**
     * @notice Public price function for Token to ETH trades with an exact output.
     * @param ethBought Amount of output ETH.
     * @return Amount of Tokens needed to buy output ETH.    
     */
    function getTokenToEthOutputPrice(uint256 ethBought) external view returns(uint256) {
        require(ethBought > 0, "exchange:getTokenToEthOutputPrice invalid parameters");
        uint256 tokenReserve = IERC20(token).balanceOf(address(this));
        return getOutputPrice(ethBought, tokenReserve, address(this).balance);
    }

    /**
     * @return Address of Token that is sold on this exchange.
     */
    function tokenAddress() external view returns(address) {
        return token;
    }

    /**
     * @return Address of factory that created this exchange.
     */
    function factoryAddress() external view returns(address){
        return factory;
    }

    /**
     * @notice Convert ETH to Tokens.
     * @dev User specifies exact input (msg.value).
     * @dev User cannot specify minimum output or deadline.
     */
    fallback() external payable {
        ethToTokenInput(msg.value, 1, block.number, msg.sender, msg.sender);
    }

    receive() external payable {}
}