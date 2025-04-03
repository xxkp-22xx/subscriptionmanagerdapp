// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract SubManager is ERC721, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    struct Subscription {
        uint256 expiresAt;
        string ipfsHash;
    }

    // Subscription price (in wei)
    uint256 public subscriptionPrice = 0.01 ether;
    
    // Royalty pools
    uint256 public creatorsPool;
    uint256 public platformPool;
    
    // Distribution ratios
    uint256 private constant CREATORS_SHARE = 90;
    uint256 private constant PLATFORM_SHARE = 10;
    
    // Token ID to Subscription mapping
    mapping(uint256 => Subscription) private _subscriptions;
    
    // IPFS hash to creator address mapping
    mapping(string => address) public contentCreators;

    event SubscriptionPurchased(
        uint256 indexed tokenId,
        address indexed subscriber,
        uint256 expiresAt,
        string ipfsHash
    );
    
    event FundsWithdrawn(
        address indexed recipient,
        uint256 amount,
        bool isPlatform
    );

    constructor() ERC721("ContentSubscription", "CSUB") {}

    // Purchase a new subscription NFT
    function purchaseSubscription(string memory ipfsHash) external payable {
        require(msg.value >= subscriptionPrice, "Insufficient payment");
        require(contentCreators[ipfsHash] != address(0), "Content not registered");
        
        // Distribute funds
        uint256 creatorsShare = (msg.value * CREATORS_SHARE) / 100;
        uint256 platformShare = (msg.value * PLATFORM_SHARE) / 100;
        
        creatorsPool += creatorsShare;
        platformPool += platformShare;
        
        // Mint NFT
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(msg.sender, tokenId);
        
        // Set subscription expiration (1 month from now)
        _subscriptions[tokenId] = Subscription({
            expiresAt: block.timestamp + 30 days,
            ipfsHash: ipfsHash
        });
        
        emit SubscriptionPurchased(tokenId, msg.sender, block.timestamp + 30 days, ipfsHash);
    }

    // Register new content (only owner can do this)
    function registerContent(string memory ipfsHash, address creator) external onlyOwner {
        require(contentCreators[ipfsHash] == address(0), "Content already registered");
        contentCreators[ipfsHash] = creator;
    }

    // Check if subscription is valid
    function isSubscriptionValid(uint256 tokenId) public view returns (bool) {
        require(_exists(tokenId), "Token does not exist");
        return _subscriptions[tokenId].expiresAt >= block.timestamp;
    }

    // Get IPFS hash if subscription is valid
    function getContentIpfsHash(uint256 tokenId) external view returns (string memory) {
        require(isSubscriptionValid(tokenId), "Subscription expired");
        return _subscriptions[tokenId].ipfsHash;
    }

    // Withdraw creator funds
    function withdrawCreatorFunds(string memory ipfsHash) external {
        address creator = contentCreators[ipfsHash];
        require(creator == msg.sender, "Not the content creator");
        
        uint256 amount = creatorsPool;
        creatorsPool = 0;
        
        (bool sent, ) = creator.call{value: amount}("");
        require(sent, "Failed to send Ether");
        
        emit FundsWithdrawn(creator, amount, false);
    }

    // Withdraw platform funds (owner only)
    function withdrawPlatformFunds() external onlyOwner {
        uint256 amount = platformPool;
        platformPool = 0;
        
        (bool sent, ) = owner().call{value: amount}("");
        require(sent, "Failed to send Ether");
        
        emit FundsWithdrawn(owner(), amount, true);
    }

    // Update subscription price (owner only)
    function setSubscriptionPrice(uint256 newPrice) external onlyOwner {
        subscriptionPrice = newPrice;
    }
}