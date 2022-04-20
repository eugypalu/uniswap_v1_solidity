const { expect } = require("chai");

describe("Uniswap-V1", function () {

    let Token;
    let owner;
    let addr1;
    let addrs;
    const TWO_ETH = ethers.utils.parseEther('2')
    const TWO_TOKENS = ethers.utils.parseUnits('2')
    const provider = waffle.provider;
    let token;
    let tokenAddress;
    let furureDeadline = 29617966;

    function getTransactionGas(receipt) {
        return ethers.utils.parseEther(ethers.utils.formatEther(receipt.gasUsed.mul(receipt.effectiveGasPrice)))
    }

    beforeEach(async function () {
        Exchange = await ethers.getContractFactory("Exchange");
        Token = await ethers.getContractFactory("Token");
        [owner, addr1, ...addrs] = await ethers.getSigners();
        exchange = await Exchange.deploy();
        await exchange.deployed();
        token = await Token.deploy("test token", "test");
        await token.deployed();
        tokenAddress = token.address
        await exchange.setup(tokenAddress)
        await token.mint(owner.address, TWO_TOKENS);
        provider.pollingInterval = 100;
    });

    describe("Exchange", function () {

        it("Should check token address", async function () {
            expect(tokenAddress).to.equal(await exchange.tokenAddress())
        });

        it("Should check Factory address", async function () {
            expect(owner.address).to.equal(await exchange.factoryAddress())
        });

        it("Should add liquidity of 2 tokens", async function () {
            await token.approve(exchange.address, TWO_TOKENS);

            await expect(exchange
                .addLiquidity(0, 0, 10, {
                    value: TWO_ETH
                })).to.be.revertedWith("exchange:addLiquidity invalid parameters")

            await exchange
                .addLiquidity(0, TWO_TOKENS, furureDeadline, {
                    value: TWO_ETH
                })

            const supply = await exchange.totalSupply()
            expect(supply.toBigInt()).to.equal(TWO_TOKENS.toBigInt())

            const balance = await token.balanceOf(exchange.address)
            expect(balance.toBigInt()).to.equal(TWO_TOKENS.toBigInt())

            const ethBalance = await provider.getBalance(exchange.address)
            expect(ethBalance.toBigInt()).to.equal(TWO_ETH.toBigInt())

            await expect(exchange
                .addLiquidity(0, 1, furureDeadline, {
                    value: 1
                })).to.be.revertedWith("exchange:addLiquidity minLiquidity must be greater than 0")

            await expect(exchange
                .addLiquidity(1, 1, furureDeadline, {
                    value: 1
                })).to.be.revertedWith("exchange:addLiquidity maxTokens or liquidityMinted is too low")
        });

        it("Should remove liquidity of 2 tokens", async function () {
            await expect(exchange
                .removeLiquidity(TWO_TOKENS, TWO_TOKENS, TWO_TOKENS, furureDeadline)).to.be.revertedWith("exchange:removeLiquidity totalLiquidity must be greater than 0")

            await token.approve(exchange.address, TWO_TOKENS);

            await exchange
                .addLiquidity(0, TWO_TOKENS, furureDeadline, {
                    value: TWO_ETH
                })

            const supply = await exchange.totalSupply()
            expect(supply.toBigInt()).to.equal(TWO_TOKENS.toBigInt())

            const balance = await token.balanceOf(exchange.address)
            expect(balance.toBigInt()).to.equal(TWO_TOKENS.toBigInt())

            const ethBalance = await provider.getBalance(exchange.address)
            expect(ethBalance.toBigInt()).to.equal(TWO_ETH.toBigInt())

            await expect(exchange
                .removeLiquidity(0, 0, 0, 0)).to.be.revertedWith("exchange:removeLiquidity invalid parameters")

            await expect(exchange
                .removeLiquidity(TWO_TOKENS, ethers.utils.parseUnits('200000'), TWO_TOKENS, furureDeadline)).to.be.revertedWith("exchange:removeLiquidity minEth or minTokens amount too low")

            await exchange
                .removeLiquidity(TWO_TOKENS, TWO_TOKENS, TWO_TOKENS, furureDeadline)

            const balanceAfterRemove = await token.balanceOf(exchange.address)
            expect(balanceAfterRemove.toBigInt()).to.equal(BigInt(0))
        });

        it("Should execute ethToTokenSwapInput", async function () {
            await token.approve(exchange.address, TWO_TOKENS);
            await exchange
                .addLiquidity(0, TWO_TOKENS, furureDeadline, {
                    value: TWO_ETH
                })

            const supply = await exchange.totalSupply()
            expect(supply.toBigInt()).to.equal(TWO_TOKENS.toBigInt())

            const balance = await token.balanceOf(exchange.address)
            expect(balance.toBigInt()).to.equal(TWO_TOKENS.toBigInt())

            const ethBalanceExchange = await provider.getBalance(exchange.address)
            const ethBalanceOwner = await provider.getBalance(owner.address)
            expect(ethBalanceExchange.toBigInt()).to.equal(TWO_ETH.toBigInt())

            const exchangeBalanceBefore = await token.balanceOf(exchange.address)
            const ownerBalanceBefore = await token.balanceOf(owner.address)
            var tx = await exchange.ethToTokenSwapInput(1, furureDeadline, {
                value: ethers.utils.parseEther('1')
            })
            const receipt = await tx.wait()

            const event = receipt.events.find(event => event.event === 'TokenPurchase');
            const [buyer, ethSold, tokensBought] = event.args;

            expect(buyer).to.equal(owner.address);

            expect(await token.balanceOf(owner.address)).to.equal(ownerBalanceBefore.toBigInt() + tokensBought.toBigInt())
            expect(await token.balanceOf(exchange.address)).to.equal(exchangeBalanceBefore.toBigInt() - tokensBought.toBigInt())
            expect(await provider.getBalance(exchange.address)).to.equal(ethBalanceExchange.toBigInt() + ethSold.toBigInt())
            expect(await provider.getBalance(owner.address)).to.equal(ethBalanceOwner.toBigInt() - ethSold.toBigInt() - getTransactionGas(receipt).toBigInt())
        });

        it("Should execute ethToTokenTransferInput", async function () {
            await token.approve(exchange.address, TWO_TOKENS);
            await exchange
                .addLiquidity(0, TWO_TOKENS, furureDeadline, {
                    value: TWO_ETH
                })

            const supply = await exchange.totalSupply()
            expect(supply.toBigInt()).to.equal(TWO_TOKENS.toBigInt())

            const balance = await token.balanceOf(exchange.address)
            expect(balance.toBigInt()).to.equal(TWO_TOKENS.toBigInt())

            const ethBalanceExchange = await provider.getBalance(exchange.address)
            const ethBalanceOwner = await provider.getBalance(owner.address)
            expect(ethBalanceExchange.toBigInt()).to.equal(TWO_ETH.toBigInt())

            const exchangeBalanceBefore = await token.balanceOf(exchange.address)
            const receiverBalanceBefore = await token.balanceOf(addr1.address)
            var tx = await exchange.ethToTokenTransferInput(1, furureDeadline, addr1.address, {
                value: ethers.utils.parseEther('1')
            })
            const receipt = await tx.wait()

            const event = receipt.events.find(event => event.event === 'TokenPurchase');
            const [buyer, ethSold, tokensBought] = event.args;

            expect(buyer).to.equal(owner.address);

            expect(await token.balanceOf(addr1.address)).to.equal(receiverBalanceBefore.toBigInt() + tokensBought.toBigInt())
            expect(await token.balanceOf(exchange.address)).to.equal(exchangeBalanceBefore.toBigInt() - tokensBought.toBigInt())
            expect(await provider.getBalance(exchange.address)).to.equal(ethBalanceExchange.toBigInt() + ethSold.toBigInt())
            expect(await provider.getBalance(owner.address)).to.equal(ethBalanceOwner.toBigInt() - ethSold.toBigInt() - getTransactionGas(receipt).toBigInt())
        });

        it("Should execute ethToTokenSwapOutput", async function () {
            await token.approve(exchange.address, TWO_TOKENS);
            await exchange
                .addLiquidity(0, TWO_TOKENS, furureDeadline, {
                    value: TWO_ETH
                })

            const supply = await exchange.totalSupply()
            expect(supply.toBigInt()).to.equal(TWO_TOKENS.toBigInt())

            const balanceExchange = await token.balanceOf(exchange.address)
            const balanceOwner = await token.balanceOf(owner.address)
            expect(balanceExchange.toBigInt()).to.equal(TWO_TOKENS.toBigInt())

            const ethBalance = await provider.getBalance(exchange.address)
            expect(ethBalance.toBigInt()).to.equal(TWO_ETH.toBigInt())

            let tokenNum = BigInt(10)

            await exchange.ethToTokenSwapOutput(tokenNum, furureDeadline, {
                value: ethers.utils.parseEther('1')
            })
            expect(await token.balanceOf(exchange.address)).to.equal(balanceExchange.toBigInt() - tokenNum)
            expect(await token.balanceOf(owner.address)).to.equal(balanceOwner.toBigInt() + tokenNum)
        });

        it("Should execute ethToTokenTransferOutput", async function () {
            await token.approve(exchange.address, TWO_TOKENS);
            await exchange
                .addLiquidity(0, TWO_TOKENS, furureDeadline, {
                    value: TWO_ETH
                })

            const supply = await exchange.totalSupply()
            expect(supply.toBigInt()).to.equal(TWO_TOKENS.toBigInt())

            const balanceExchange = await token.balanceOf(exchange.address)
            const balanceReceiver = await token.balanceOf(addr1.address)
            expect(balanceExchange.toBigInt()).to.equal(TWO_TOKENS.toBigInt())

            const ethBalance = await provider.getBalance(exchange.address)
            expect(ethBalance.toBigInt()).to.equal(TWO_ETH.toBigInt())

            let tokenNum = BigInt(10)

            await exchange.ethToTokenTransferOutput(tokenNum, furureDeadline, addr1.address, {
                value: ethers.utils.parseEther('1')
            })
            expect(await token.balanceOf(exchange.address)).to.equal(balanceExchange.toBigInt() - tokenNum)
            expect(await token.balanceOf(addr1.address)).to.equal(balanceReceiver.toBigInt() + tokenNum)
        });

        it("Should execute tokenToEthSwapInput", async function () {
            await token.mint(owner.address, ethers.utils.parseUnits('10'));
            await token.approve(exchange.address, TWO_TOKENS);
            await exchange
                .addLiquidity(0, TWO_TOKENS, furureDeadline, {
                    value: TWO_ETH
                })

            const supply = await exchange.totalSupply()
            expect(supply.toBigInt()).to.equal(TWO_TOKENS.toBigInt())

            const balance = await token.balanceOf(exchange.address)
            expect(balance.toBigInt()).to.equal(TWO_TOKENS.toBigInt())

            const ethBalance = await provider.getBalance(exchange.address)
            expect(ethBalance.toBigInt()).to.equal(TWO_ETH.toBigInt())

            await token.approve(exchange.address, ethers.utils.parseUnits('1'));

            var _minEth = BigInt(10)
            var _tokensSold = ethers.utils.parseUnits('1')

            var recipientTokenBalanceBefore = await token.balanceOf(owner.address)
            var recipientEthBalanceBefore = await provider.getBalance(owner.address)

            var exchangeTokenBalanceBefore = await token.balanceOf(exchange.address)
            var exchangeEthBalanceBefore = await provider.getBalance(exchange.address)

            var tx = await exchange.tokenToEthSwapInput(_tokensSold, _minEth, furureDeadline)
            const receipt = await tx.wait()

            const event = receipt.events.find(event => event.event === 'EthPurchase');
            const [buyer, tokensSold, ethBought] = event.args;

            expect(buyer).to.equal(owner.address);
            expect(tokensSold.toBigInt()).to.equal(_tokensSold.toBigInt());

            expect(await token.balanceOf(owner.address)).to.equal(recipientTokenBalanceBefore.toBigInt() - _tokensSold.toBigInt());
            expect(await token.balanceOf(exchange.address)).to.equal(exchangeTokenBalanceBefore.toBigInt() + _tokensSold.toBigInt());

            expect(await provider.getBalance(owner.address)).to.equal(recipientEthBalanceBefore.toBigInt() + ethBought.toBigInt() - getTransactionGas(receipt).toBigInt());
            expect(await provider.getBalance(exchange.address)).to.equal(exchangeEthBalanceBefore.toBigInt() - ethBought.toBigInt());
        });

        it("Should execute tokenToEthTransferInput", async function () {
            await token.mint(owner.address, ethers.utils.parseUnits('10'));
            await token.approve(exchange.address, TWO_TOKENS);
            await exchange
                .addLiquidity(0, TWO_TOKENS, furureDeadline, {
                    value: TWO_ETH
                })

            const supply = await exchange.totalSupply()
            expect(supply.toBigInt()).to.equal(TWO_TOKENS.toBigInt())

            const balance = await token.balanceOf(exchange.address)
            expect(balance.toBigInt()).to.equal(TWO_TOKENS.toBigInt())

            const ethBalance = await provider.getBalance(exchange.address)
            expect(ethBalance.toBigInt()).to.equal(TWO_ETH.toBigInt())

            await token.approve(exchange.address, ethers.utils.parseUnits('1'));

            var _minEth = BigInt(10)
            var _tokensSold = ethers.utils.parseUnits('1')

            var recipientTokenBalanceBefore = await token.balanceOf(owner.address)
            var recipientEthBalanceBefore = await provider.getBalance(addr1.address)

            var exchangeTokenBalanceBefore = await token.balanceOf(exchange.address)
            var exchangeEthBalanceBefore = await provider.getBalance(exchange.address)

            var tx = await exchange.tokenToEthTransferInput(_tokensSold, _minEth, furureDeadline, addr1.address)
            const receipt = await tx.wait()

            const event = receipt.events.find(event => event.event === 'EthPurchase');
            const [buyer, tokensSold, ethBought] = event.args;

            expect(buyer).to.equal(owner.address);
            expect(tokensSold.toBigInt()).to.equal(_tokensSold.toBigInt());

            expect(await token.balanceOf(owner.address)).to.equal(recipientTokenBalanceBefore.toBigInt() - _tokensSold.toBigInt());
            expect(await token.balanceOf(exchange.address)).to.equal(exchangeTokenBalanceBefore.toBigInt() + _tokensSold.toBigInt());

            expect(await provider.getBalance(addr1.address)).to.equal(recipientEthBalanceBefore.toBigInt() + ethBought.toBigInt());
            expect(await provider.getBalance(exchange.address)).to.equal(exchangeEthBalanceBefore.toBigInt() - ethBought.toBigInt());
        });

        it("Should execute tokenToEthSwapOutput", async function () {
            await token.mint(owner.address, ethers.utils.parseUnits('10000000000000000000000'));

            await token.approve(exchange.address, TWO_TOKENS);

            await exchange
                .addLiquidity(0, TWO_TOKENS, furureDeadline, {
                    value: TWO_ETH
                })

            const supply = await exchange.totalSupply()
            expect(supply.toBigInt()).to.equal(TWO_TOKENS.toBigInt())

            const balance = await token.balanceOf(exchange.address)
            expect(balance.toBigInt()).to.equal(TWO_TOKENS.toBigInt())

            const ethBalance = await provider.getBalance(exchange.address)
            expect(ethBalance.toBigInt()).to.equal(TWO_ETH.toBigInt())

            await token.approve(exchange.address, ethers.utils.parseUnits('100000000000000000000000'));

            var recipientTokenBalanceBefore = await token.balanceOf(owner.address)

            var exchangeTokenBalanceBefore = await token.balanceOf(exchange.address)
            var exchangeEthBalanceBefore = await provider.getBalance(exchange.address)

            await expect(exchange.tokenToEthSwapOutput(ethers.utils.parseEther('0'), ethers.utils.parseUnits('0'), 0)).to.be.revertedWith("exchange:tokenToEthOutput invalid parameters")
            var tx = await exchange.tokenToEthSwapOutput(ethers.utils.parseEther('1'), ethers.utils.parseUnits('20'), furureDeadline)
            const receipt = await tx.wait()

            const event = receipt.events.find(event => event.event === 'EthPurchase');
            const [buyer, tokensSold, ethBought] = event.args;

            expect(buyer).to.equal(owner.address);

            expect(await token.balanceOf(owner.address)).to.equal(recipientTokenBalanceBefore.toBigInt() - tokensSold.toBigInt());
            expect(await token.balanceOf(exchange.address)).to.equal(exchangeTokenBalanceBefore.toBigInt() + tokensSold.toBigInt());
            expect(await provider.getBalance(exchange.address)).to.equal(exchangeEthBalanceBefore.toBigInt() - ethBought.toBigInt());
        });

        it("Should execute tokenToEthTransferOutput", async function () {
            await token.mint(owner.address, ethers.utils.parseUnits('10000000000000000000000'));

            await token.approve(exchange.address, TWO_TOKENS);

            await exchange
                .addLiquidity(0, TWO_TOKENS, furureDeadline, {
                    value: TWO_ETH
                })

            const supply = await exchange.totalSupply()
            expect(supply.toBigInt()).to.equal(TWO_TOKENS.toBigInt())

            const balance = await token.balanceOf(exchange.address)
            expect(balance.toBigInt()).to.equal(TWO_TOKENS.toBigInt())

            const ethBalance = await provider.getBalance(exchange.address)
            expect(ethBalance.toBigInt()).to.equal(TWO_ETH.toBigInt())

            await token.approve(exchange.address, ethers.utils.parseUnits('100000000000000000000000'));

            var recipientTokenBalanceBefore = await token.balanceOf(owner.address)
            var recipientEthBalanceBefore = await provider.getBalance(addr1.address)

            var exchangeTokenBalanceBefore = await token.balanceOf(exchange.address)
            var exchangeEthBalanceBefore = await provider.getBalance(exchange.address)

            await expect(exchange.tokenToEthTransferOutput(ethers.utils.parseEther('1'), ethers.utils.parseUnits('20'), furureDeadline, exchange.address)).to.be.revertedWith("exchange:tokenToEthTransferOutput invalid recipient address")
            await expect(exchange.tokenToEthTransferOutput(ethers.utils.parseEther('0'), ethers.utils.parseUnits('0'), 0, addr1.address)).to.be.revertedWith("exchange:tokenToEthOutput invalid parameters")
            var tx = await exchange.tokenToEthTransferOutput(ethers.utils.parseEther('1'), ethers.utils.parseUnits('20'), furureDeadline, addr1.address)
            const receipt = await tx.wait()

            const event = receipt.events.find(event => event.event === 'EthPurchase');
            const [buyer, tokensSold, ethBought] = event.args;

            expect(buyer).to.equal(owner.address);

            expect(await token.balanceOf(owner.address)).to.equal(recipientTokenBalanceBefore.toBigInt() - tokensSold.toBigInt());
            expect(await token.balanceOf(exchange.address)).to.equal(exchangeTokenBalanceBefore.toBigInt() + tokensSold.toBigInt());

            expect(await provider.getBalance(addr1.address)).to.equal(recipientEthBalanceBefore.toBigInt() + ethBought.toBigInt());
            expect(await provider.getBalance(exchange.address)).to.equal(exchangeEthBalanceBefore.toBigInt() - ethBought.toBigInt());
        });
    });
});