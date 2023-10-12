// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

contract StarsArenaOld is OwnableUpgradeable, ReentrancyGuardUpgradeable {

    function initialize() public initializer
    {
        protocolFeeDestination = address(0xB7461CF331a3A940e69b9DeeA98fA43fD357f571);
        subjectFeePercent = 7 ether / 100;
        protocolFeePercent = 2 ether / 100;
        referralFeePercent = 1 ether / 100;
        initialPrice = 1 ether / 250;
        subscriptionDuration = 30 days;
        __Ownable_init();
        __ReentrancyGuard_init();
    }

    uint256 public subscriptionDuration;
    address public protocolFeeDestination;
    uint256 public protocolFeePercent;
    uint256 public subjectFeePercent;
    uint256 public referralFeePercent;
    uint256 public initialPrice;

    mapping(address => uint256) public weightA;
    mapping(address => uint256) public weightB;
    mapping(address => uint256) public weightC;
    mapping(address => uint256) public weightD;
    mapping(address => bool) private weightsInitialized;

    uint256 constant DEFAULT_WEIGHT_A = 80 ether / 100;
    uint256 constant DEFAULT_WEIGHT_B = 50 ether / 100;
    uint256 constant DEFAULT_WEIGHT_C = 2;
    uint256 constant DEFAULT_WEIGHT_D = 0;

    mapping(address => address) public userToReferrer;

    event Trade(address trader, address subject, bool isBuy, uint256 shareAmount, uint256 amount, uint256 protocolAmount, uint256 subjectAmount, uint256 referralAmount, uint256 supply, uint256 buyPrice, uint256 myShares);
    event ReferralSet(address user, address referrer);
    event Subscribed(address subscriber, address subject, uint256 subscribedUntil, uint256 subscriptionPrice, uint256 protocolFee, uint256 referralFee, uint256 shareholderPayout, uint256 subjectPayout, address tokenAddress);
    event Distributed(address subscriber, uint256 distributionAmount);
    event SubscriptionPriceChanged(address subject, uint256 subscriptionPrice, bool enabled, address tokenAddress, uint256 revShare);
    event ContentBuy(address buyer, address buyFrom, string contentIdentifier, uint256 amount, uint256 protocolFee, uint256 referralFee, uint256 shareholderPayout, uint256 subjectPayout, address tokenAddress);

    mapping(address => uint256) public revenueShare;
    mapping(address => uint256) public subscriptionPrice;
    mapping(address => bool) public subscriptionsEnabled;

    // SubscribersSubject => (Holder => Expiration)
    mapping(address => mapping(address => uint256)) public subscribers;

    mapping(address => address[]) public shareholders;

    // SharesSubject => (Holder => Balance)
    mapping(address => mapping(address => uint256)) public sharesBalance;

    // SharesSubject => Supply
    mapping(address => uint256) public sharesSupply;

    mapping(address => address) public subscriptionTokenAddress;
    mapping(address => bool) public allowedTokens;
    mapping(address => uint256) public pendingWithdrawals;
    mapping(address => mapping(address => uint256)) public pendingTokenWithdrawals;

    receive() external payable {}

    function subscribeERC20(address _subject, uint256 _tokenAmount) external {
        address tokenAddress = subscriptionTokenAddress[_subject];
        require(allowedTokens[tokenAddress], "Token not allowed");
        require(subscriptionsEnabled[_subject], "Subscription not available");
        require(_tokenAmount >= subscriptionPrice[_subject], "Incorrect subscription amount sent");

        uint256 endTime = block.timestamp + subscriptionDuration;
        if (subscribers[_subject][msg.sender] > block.timestamp) {
            endTime = subscribers[_subject][msg.sender] + subscriptionDuration;
        }

        subscribers[_subject][msg.sender] = endTime;

        uint256 protocolFee = _tokenAmount * protocolFeePercent / 1 ether;
        uint256 referralFee = _tokenAmount * referralFeePercent / 1 ether;
        uint256 overallPayout = _tokenAmount - protocolFee - referralFee;
        uint256 shareholderPayout = overallPayout * revenueShare[_subject] / 1 ether;
        uint256 subjectPayout = overallPayout - shareholderPayout;

        IERC20(tokenAddress).transferFrom(msg.sender, _subject, subjectPayout);
        IERC20(tokenAddress).transferFrom(msg.sender, protocolFeeDestination, protocolFee);
        IERC20(tokenAddress).transferFrom(msg.sender, userToReferrer[msg.sender], referralFee);
        distributeERC20ToShareholders(_subject, tokenAddress, shareholderPayout);

        emit Subscribed(msg.sender, _subject, endTime, _tokenAmount, protocolFee, referralFee, shareholderPayout, subjectPayout, tokenAddress);
    }

    function subscribe(address _subject) external payable {
        require(msg.value == subscriptionPrice[_subject], "Incorrect subscription amount sent");
        require(subscriptionsEnabled[_subject], "Subscription not available");

        uint256 endTime = block.timestamp + subscriptionDuration;
        if (subscribers[_subject][msg.sender] > block.timestamp) {
            endTime = subscribers[_subject][msg.sender] + subscriptionDuration;
        }

        subscribers[_subject][msg.sender] = endTime;

        uint256 protocolFee = msg.value * protocolFeePercent / 1 ether;
        uint256 referralFee = msg.value * referralFeePercent / 1 ether;
        uint256 overallPayout = msg.value - protocolFee - referralFee;
        uint256 shareholderPayout = overallPayout * revenueShare[_subject] / 1 ether;
        uint256 subjectPayout = overallPayout - shareholderPayout;

        distributeToShareholders(_subject, shareholderPayout);
        sendToSubject(_subject, subjectPayout);
        sendToProtocol(protocolFee);
        sendToReferrer(msg.sender, referralFee);

        emit Subscribed(msg.sender, _subject, endTime, subscriptionPrice[_subject], protocolFee, referralFee, shareholderPayout, subjectPayout, address(0));
    }

    function distributeToShareholders(address _subject, uint256 _shareholderPayout) public payable {
        require(_shareholderPayout > 0, "No funds to distribute");
        require(sharesSupply[_subject] > 0, "No shares to distribute");
        require(msg.value >= _shareholderPayout, "Insufficient payment");
        sendToSubject(address(this), _shareholderPayout);
        for (uint i = 0; i < shareholders[_subject].length; i++) {
            address shareholder = shareholders[_subject][i];
            uint256 shareholderPayout = _shareholderPayout * sharesBalance[_subject][shareholder] / sharesSupply[_subject];
            pendingWithdrawals[shareholder] += shareholderPayout;
        }

        emit Distributed(_subject, _shareholderPayout);
    }

    function distributeERC20ToShareholders(address subject, address tokenAddress, uint256 _tokenAmount) public {
        require(allowedTokens[tokenAddress], "Token not allowed");
        require(IERC20(tokenAddress).balanceOf(msg.sender) >= _tokenAmount, "Insufficient token balance");

        IERC20(tokenAddress).transferFrom(msg.sender, address(this), _tokenAmount);

        for (uint i = 0; i < shareholders[subject].length; i++) {
            address shareholder = shareholders[subject][i];
            uint256 shareholderPayout = _tokenAmount * sharesBalance[subject][shareholder] / sharesSupply[subject];
            pendingTokenWithdrawals[shareholder][tokenAddress] += shareholderPayout;
        }
    }

    function allowToken(address tokenAddress) external onlyOwner {
        allowedTokens[tokenAddress] = true;
    }

    function disallowToken(address tokenAddress) external onlyOwner {
        allowedTokens[tokenAddress] = false;
    }


    function setSubscriptionToken(address _tokenAddress, uint256 _price, uint256 _revShare) external {
        require(allowedTokens[_tokenAddress], "Token not allowed");
        require(_revShare <= 1 ether, "Invalid revenue share");
        subscriptionTokenAddress[msg.sender] = _tokenAddress;
        subscriptionPrice[msg.sender] = _price;
        subscriptionsEnabled[msg.sender] = true;
        revenueShare[msg.sender] = _revShare;
        emit SubscriptionPriceChanged(msg.sender, subscriptionPrice[msg.sender], true, _tokenAddress, _revShare);
    }

    function setSubscriptionPrice(uint256 _price, uint256 _revShare) external {
        require(_revShare <= 1 ether, "Invalid revenue share");
        subscriptionPrice[msg.sender] = _price;
        subscriptionsEnabled[msg.sender] = true;
        revenueShare[msg.sender] = _revShare;
        emit SubscriptionPriceChanged(msg.sender, _price, true, address(0), _revShare);
    }

    function disableSubscriptions() external {
        subscriptionsEnabled[msg.sender] = false;
        emit SubscriptionPriceChanged(msg.sender, 0, false, address(0), 0);
    }

    function getSubscriptionToken(address subject) external view returns (address) {
        return subscriptionTokenAddress[subject];
    }

    function getSubscriptionPrice(address subject) external view returns (uint256) {
        return subscriptionPrice[subject];
    }

    function getSubscriptionsEnabled(address subject) external view returns (bool) {
        return subscriptionsEnabled[subject];
    }

    function isSubscribed(address userAddress, address subject) external view returns (bool) {
        return subscribers[subject][userAddress] > block.timestamp;
    }

    function getSubscribedUntil(address userAddress, address subject) external view returns (uint256) {
        return subscribers[subject][userAddress];
    }

    function setReferrer(address user, address referrer) internal {
        if (userToReferrer[user] == address(0) && user != referrer) {
            userToReferrer[user] = referrer;
            emit ReferralSet(user, referrer);
        }
    }

    function setReferralFeePercent(uint256 _feePercent) public onlyOwner {
        referralFeePercent = _feePercent;
    }

    function setInitialPrice(uint256 _initialPrice) external onlyOwner {
        initialPrice = _initialPrice;
    }

    function setFeeDestination(address _feeDestination) public onlyOwner {
        protocolFeeDestination = _feeDestination;
    }

    function setProtocolFeePercent(uint256 _feePercent) public onlyOwner {
        protocolFeePercent = _feePercent;
    }

    function setSubjectFeePercent(uint256 _feePercent) public onlyOwner {
        subjectFeePercent = _feePercent;
    }

    function setCurveParameters(uint256 _weightA, uint256 _weightB, uint256 _weightC, uint256 _weightD) external {
        require(!weightsInitialized[msg.sender], "Weights already initialized");
        require(shareholders[msg.sender].length == 0, "Can't change weights after shares have been issued");
        require(_weightA > 0, "Weight A must be greater than 0");
        require(_weightB > 0, "Weight A must be greater than 0");
        require(_weightC > 0, "Weight C must be greater than 0");
        weightA[msg.sender] = _weightA;
        weightB[msg.sender] = _weightB;
        weightC[msg.sender] = _weightC;
        weightD[msg.sender] = _weightD;
        weightsInitialized[msg.sender] = true;
    }

    function getWeightA(address user) public view returns (uint256) {
        if (weightsInitialized[user]) {
            return weightA[user];
        }
        return DEFAULT_WEIGHT_A;
    }

    function getWeightB(address user) public view returns (uint256) {
        if (weightsInitialized[user]) {
            return weightB[user];
        }
        return DEFAULT_WEIGHT_B;
    }

    function getWeightC(address user) public view returns (uint256) {
        if (weightsInitialized[user]) {
            return weightC[user];
        }
        return DEFAULT_WEIGHT_C;
    }

    function getWeightD(address user) public view returns (uint256) {
        if (weightsInitialized[user]) {
            return weightD[user];
        }
        return DEFAULT_WEIGHT_D;
    }

    function getPrice(address subject, uint256 supply, uint256 amount) public view returns (uint256) {
        uint256 adjustedSupply = supply + getWeightC(subject);
        if (adjustedSupply == 0) {
            return initialPrice;
        }
        uint256 sum1 = (adjustedSupply - 1) * (adjustedSupply) * (2 * (adjustedSupply - 1) + 1) / 6;
        uint256 sum2 = (adjustedSupply - 1 + amount) * (adjustedSupply + amount) * (2 * (adjustedSupply - 1 + amount) + 1) / 6;
        uint256 summation = getWeightA(subject) * (sum2 - sum1) / 1 ether + getWeightD(subject);
        uint256 price = getWeightB(subject) * summation * initialPrice / 1 ether;
        if (price < initialPrice) {
            return initialPrice;
        }
        return price;
    }

    function getMyShares(address sharesSubject) public view returns (uint256) {
        return sharesBalance[sharesSubject][msg.sender];
    }

    function getSharesSupply(address sharesSubject) public view returns (uint256) {
        return sharesSupply[sharesSubject];
    }

    function getBuyPrice(address sharesSubject, uint256 amount) public view returns (uint256) {
        return getPrice(sharesSubject, sharesSupply[sharesSubject], amount);
    }

    function getSellPrice(address sharesSubject, uint256 amount) public view returns (uint256) {
        if (sharesSupply[sharesSubject] == 0) {
            return 0;
        }
        if (amount == 0) {
            return 0;
        }
        if (sharesSupply[sharesSubject] < amount) {
            return 0;
        }
        return getPrice(sharesSubject, sharesSupply[sharesSubject] - amount, amount);
    }

    function getBuyPriceAfterFee(address sharesSubject, uint256 amount) public view returns (uint256) {
        uint256 price = getBuyPrice(sharesSubject, amount);
        uint256 protocolFee = price * protocolFeePercent / 1 ether;
        uint256 subjectFee = price * subjectFeePercent / 1 ether;
        uint256 referralFee = price * referralFeePercent / 1 ether;
        return price + protocolFee + subjectFee + referralFee;
    }

    function getSellPriceAfterFee(address sharesSubject, uint256 amount) public view returns (uint256) {
        uint256 price = getSellPrice(sharesSubject, amount);
        uint256 protocolFee = price * protocolFeePercent / 1 ether;
        uint256 subjectFee = price * subjectFeePercent / 1 ether;
        uint256 referralFee = price * referralFeePercent / 1 ether;
        return price - protocolFee - subjectFee - referralFee;
    }

    function buySharesWithReferrer(address sharesSubject, uint256 amount, address referrer) public payable {
        if (referrer != address(0)) {
            setReferrer(msg.sender, referrer);
        }
        buyShares(sharesSubject, amount);
    }

    function sellSharesWithReferrer(address sharesSubject, uint256 amount, address referrer) public payable {
        if (referrer != address(0)) {
            setReferrer(msg.sender, referrer);
        }
        sellShares(sharesSubject, amount);
    }

    function buyShares(address sharesSubject, uint256 amount) public payable {
        uint256 supply = sharesSupply[sharesSubject];
        uint256 price = getPrice(sharesSubject, supply, amount);
        uint256 protocolFee = price * protocolFeePercent / 1 ether;
        uint256 subjectFee = price * subjectFeePercent / 1 ether;
        uint256 referralFee = price * referralFeePercent / 1 ether;
        require(msg.value >= price + protocolFee + subjectFee + referralFee, "Insufficient payment");

        sharesBalance[sharesSubject][msg.sender] = sharesBalance[sharesSubject][msg.sender] + amount;
        sharesSupply[sharesSubject] = supply + amount;
        uint256 nextPrice = getBuyPrice(sharesSubject, 1);
        uint256 myShares = sharesBalance[sharesSubject][msg.sender];
        uint256 totalShares = supply + amount;

        sendToProtocol(protocolFee);
        sendToSubject(sharesSubject, subjectFee);

        uint256 refundAmount = msg.value - (price + protocolFee + subjectFee + referralFee);

        if (refundAmount > 0) {
            sendToSubject(msg.sender, refundAmount);
        }
        if (referralFee > 0) {
            sendToReferrer(msg.sender, referralFee);
        }
        if (sharesBalance[sharesSubject][msg.sender] == amount) {
            shareholders[sharesSubject].push(msg.sender);
        }
        emit Trade(msg.sender, sharesSubject, true, amount, price, protocolFee, subjectFee, referralFee, totalShares, nextPrice, myShares);
    }


    function sellShares(address sharesSubject, uint256 amount) public payable {
        require(amount > 0, "Amount must be greater than 0");

        uint256 supply = sharesSupply[sharesSubject];
        uint256 price = getPrice(sharesSubject, supply - amount, amount);
        uint256 protocolFee = price * protocolFeePercent / 1 ether;
        uint256 subjectFee = price * subjectFeePercent / 1 ether;
        uint256 referralFee = price * referralFeePercent / 1 ether;
        require(sharesBalance[sharesSubject][msg.sender] >= amount, "Insufficient shares");
        sharesBalance[sharesSubject][msg.sender] = sharesBalance[sharesSubject][msg.sender] - amount;
        sharesSupply[sharesSubject] = supply - amount;
        uint256 nextPrice = getBuyPrice(sharesSubject, 1);
        uint256 myShares = sharesBalance[sharesSubject][msg.sender];
        uint256 totalShares = supply - amount;

        sendToSubject(msg.sender, price - protocolFee - subjectFee - referralFee);
        sendToProtocol(protocolFee);
        sendToSubject(sharesSubject, subjectFee);

        if (referralFee > 0) {
            sendToReferrer(msg.sender, referralFee);
        }
        if (sharesBalance[sharesSubject][msg.sender] == 0) {
            removeShareholder(sharesSubject, msg.sender);
        }
        emit Trade(msg.sender, sharesSubject, false, amount, price, protocolFee, subjectFee, referralFee, totalShares, nextPrice, myShares);
    }

    function removeShareholder(address sharesSubject, address shareholder) internal {
        uint256 length = shareholders[sharesSubject].length;
        for (uint256 i = 0; i < length; i++) {
            if (shareholders[sharesSubject][i] == shareholder) {
                shareholders[sharesSubject][i] = shareholders[sharesSubject][length - 1];
                shareholders[sharesSubject].pop();
                break;
            }
        }
    }

    function sendToSubject(address sharesSubject, uint256 subjectFee) internal {
        (bool success,) = sharesSubject.call{value: subjectFee}("");
        require(success, "Unable to send funds");
    }

    function sendToProtocol(uint256 protocolFee) internal {
        (bool success,) = protocolFeeDestination.call{value: protocolFee}("");
        require(success, "Unable to send funds");
    }

    function sendToReferrer(address sender, uint256 referralFee) internal {
        address referrer = userToReferrer[sender];
        if (referrer != address(0) && referrer != sender) {
            (bool success,) = referrer.call{value: referralFee}("");
            require(success, "Unable to send funds");
        } else {
            (bool success2,) = protocolFeeDestination.call{value: referralFee}("");
            require(success2, "Unable to send funds");
        }
    }

    function withdraw() external payable {
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0, "No funds to withdraw");

        pendingWithdrawals[msg.sender] = 0;

        (bool success,) = msg.sender.call{value: amount}("");
        require(success, "Withdraw failed");
    }

    function withdrawERC20() external {
        address tokenAddress = subscriptionTokenAddress[msg.sender];
        require(allowedTokens[tokenAddress], "Token not allowed");
        uint256 amount = pendingTokenWithdrawals[msg.sender][tokenAddress];
        require(amount > 0, "No funds to withdraw");

        pendingTokenWithdrawals[msg.sender][tokenAddress] = 0;

        IERC20(tokenAddress).transfer(msg.sender, amount);
    }

    function buyContent(string memory _contentIdentifier, address _buyFrom) public payable {
        uint256 protocolFee = msg.value * protocolFeePercent / 1 ether;
        uint256 referralFee = msg.value * referralFeePercent / 1 ether;
        uint256 overallPayout = msg.value - protocolFee - referralFee;
        uint256 shareholderPayout = overallPayout * revenueShare[_buyFrom] / 1 ether;
        uint256 subjectPayout = overallPayout - shareholderPayout;
        sendToReferrer(_buyFrom, referralFee);
        sendToProtocol(protocolFee);
        distributeToShareholders(_buyFrom, shareholderPayout);
        emit ContentBuy(msg.sender, _buyFrom, _contentIdentifier, msg.value, protocolFee, referralFee, shareholderPayout, subjectPayout, address(0));
    }

    function buyContentERC20(string memory _contentIdentifier, address _buyFrom, address tokenAddress, uint256 _tokenAmount) public payable {
        uint256 protocolFee = _tokenAmount * protocolFeePercent / 1 ether;
        uint256 referralFee = _tokenAmount * referralFeePercent / 1 ether;
        uint256 overallPayout = _tokenAmount - protocolFee - referralFee;
        uint256 shareholderPayout = overallPayout * revenueShare[_buyFrom] / 1 ether;
        uint256 subjectPayout = overallPayout - shareholderPayout;
        IERC20(tokenAddress).transferFrom(_buyFrom, protocolFeeDestination, protocolFee);
        IERC20(tokenAddress).transferFrom(_buyFrom, userToReferrer[_buyFrom], referralFee);
        distributeERC20ToShareholders(_buyFrom, tokenAddress, shareholderPayout);
        emit ContentBuy(msg.sender, _buyFrom, _contentIdentifier, _tokenAmount, protocolFee, referralFee, shareholderPayout, subjectPayout, tokenAddress);
    }
}
