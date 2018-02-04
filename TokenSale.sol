pragma solidity ^0.4.11;

import './CryptomonToken.sol';

/**
 * @title Crowdsale
 * @dev Crowdsale is a base contract for managing a token crowdsale.
 * Crowdsales have a start and end timestamps, where investors can make
 * token purchases and the crowdsale will assign them tokens based
 * on a token per ETH rate. Funds collected are forwarded to a wallet
 * as they arrive.
 */
contract Crowdsale {
    using SafeMath for uint256;

    // The token being sold
    CryptomonToken public token;

    // start and end timestamps where investments are allowed (both inclusive)
    uint256 public startTime;
    uint256 public endTime;

    // address where funds are collected
    address public wallet;

    // amount of raised money in wei
    uint256 public weiRaised;

    /**
     * event for token purchase logging
     * @param purchaser who paid for the tokens
     * @param beneficiary who got the tokens
     * @param value weis paid for purchase
     * @param amount amount of tokens purchased
     */
    event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);


    function Crowdsale(uint256 _startTime, uint256 _endTime, address _wallet, CryptomonToken _tokenAddress) {
        require(_startTime >= now);
        require(_endTime >= _startTime);
        require(_wallet != 0x0);

        token = _tokenAddress;
        startTime = _startTime;
        endTime = _endTime;
        wallet = _wallet;
    }


    // fallback function can be used to buy tokens
    function () payable {
        buyTokens(msg.sender);
    }

    // low level token purchase function
    function buyTokens(address beneficiary) private {}

    // send ether to the fund collection wallet
    // override to create custom fund forwarding mechanisms
    function forwardFunds() internal {
        wallet.transfer(msg.value);
    }

    // @return true if the transaction can buy tokens
    function validPurchase() internal constant returns (bool) {
        bool withinPeriod = now >= startTime && now <= endTime;
        bool nonZeroPurchase = msg.value != 0;
        return withinPeriod && nonZeroPurchase;
    }

    // @return true if crowdsale event has ended
    function hasEnded() public constant returns (bool) {
        return now > endTime;
    }


}

/**
 * @title FinalizableCrowdsale
 * @dev Extension of Crowdsale where an owner can do extra work
 * after finishing.
 */
contract FinalizableCrowdsale is Crowdsale, Ownable {
    using SafeMath for uint256;

    bool public isFinalized = false;

    event Finalized();

    /**
     * @dev Must be called after crowdsale ends, to do some extra finalization
     * work. Calls the contract's finalization function.
     */
    function finalize() onlyOwner public {
        require(!isFinalized);
        require(hasEnded());

        finalization();
        Finalized();

        isFinalized = true;
    }

    /**
     * @dev Can be overridden to add finalization logic. The overriding function
     * should call super.finalization() to ensure the chain of finalization is
     * executed entirely.
     */
    function finalization() internal {
    }
}


/**
 * @title Cryptomon token pre-sale
 * @dev Curated pre-sale contract based on OpenZeppelin implementations
 */
contract TokenSale is FinalizableCrowdsale {

    // define TokenSale depended variables
    uint256 public tokensSold;
    uint256 public toBeSold;
    uint256 public price;

    event SaleExtended(uint256 newEndTime);

    /**
     * @dev The constructor
     * @param _token address is the address of the token contract (ownership is required to handle it)
     * @param _startTime uint256 is a timestamp of presale start
     * @param _endTime uint256 is a timestamp of presale end (can be changed later)
     * @param _wallet address is the address the funds will go to - it's not a multisig
     * @param _toBeSold uint256 number of tokens to be sold on this presale, in wei, e.g. 1969482*1000000000
     * @param _price uint256 presale price e.g. 692981
     */
    function TokenSale(CryptomonToken _token, uint256 _startTime, uint256 _endTime, address _wallet, uint256 _toBeSold, uint256 _price)
    FinalizableCrowdsale()
    Crowdsale(_startTime, _endTime, _wallet, _token)
    {
        toBeSold = _toBeSold;
        price = _price;
    }

    /*
     * Buy in function to be called mostly from the fallback function
     * @dev kept public in order to buy for someone else
     * @param beneficiary address
     */
    function buyTokens(address beneficiary) private {
        require(beneficiary != 0x0);
        require(validPurchase());

        uint256 weiAmount = msg.value;

        // calculate token amount to be created
        uint256 toGet = howMany(msg.value);

        require((toGet > 0) && (toGet.add(tokensSold) <= toBeSold));

        // update state
        weiRaised = weiRaised.add(weiAmount);
        tokensSold = tokensSold.add(toGet);

        token.mint(beneficiary, toGet);
        TokenPurchase(msg.sender, beneficiary, weiAmount, toGet);

        forwardFunds();
    }

    /*
     * Helper token emission functions
     * @param value uint256 of the wei amount that gets invested
     * @return uint256 of how many tokens can one get
     */
    function howMany(uint256 value) view public returns (uint256){
        return (value/price);
    }

    /*
     * Adjust finalization to transfer token ownership to the fund holding address for further use
     */
    function finalization() internal {
        token.transferOwnership(wallet);
    }

    /*
     * Optional settings to extend the duration
     * @param _newEndTime uint256 is the new time stamp of extended presale duration
     */
    function extendDuration(uint256 _newEndTime) onlyOwner {
        require(!isFinalized);
        require(endTime < _newEndTime);
        endTime = _newEndTime;
        SaleExtended(_newEndTime);
    }
}
