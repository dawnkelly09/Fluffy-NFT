// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract MuncheezNFT is ERC721, IERC2981, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;
    using Strings for uint256;
    Counters.Counter private tokenCounter;

    string  public                  baseURI;
    string  public                  verificationHash;
    address private                 openSeaProxyRegistryAddress;
    bool    private                 isOpenSeaProxyActive = true;

    //set at one over desired max per wallet to allow simple < check
    uint256 public constant         MAX_MUNCHEEZ_PER_WALLET = 3;
    uint256 public                  maxMuncheez;
    //same price will be used for WL & Public sales
    uint256 public constant         NFT_SALE_PRICE = 0.06 ether;
    bool    public                  isPublicSaleActive;
    uint256 public                  maxWhitelistSaleMuncheez;
    bytes32 public                  whitelistSaleMerkleRoot;
    bool    public                  isWhitelistSaleActive;

    uint256 public                  maxGiftedMuncheez;
    uint256 public                  numGiftedMuncheez;
    bytes32 public                  claimListMerkleRoot;
    address public                  royaltyReceiverAddress;



    mapping(address => uint256) public whitelistMintCounts;
    mapping(address => bool) public claimed;



    //ACCESS CONTROL AND STATE MODIFIERS

    modifier publicSaleActive() {
        require(isPublicSaleActive, "Public sale is not open");
        _;
    }

    modifier whitelistSaleActive() {
        require(isWhitelistSaleActive, "Whitelist sale is not open");
        _;
    }

    modifier isCorrectPayment(uint256 price, uint256 numberOfTokens) {
        require(
            price * numberOfTokens == msg.value,
            "Incorrect ETH value sent"
        );
        _;
    }

    modifier canMintMuncheez(uint256 numberOfTokens) {
        require(
            tokenCounter.current() + numberOfTokens <=
                maxMuncheez - maxGiftedMuncheez,
            "Not enough Muncheez remaining to mint"
        );
        _;
    }

    modifier maxMuncheezPerWallet(uint256 numberOfTokens) {
        require(
            balanceOf(msg.sender) + numberOfTokens <= MAX_MUNCHEEZ_PER_WALLET,
            "Max Muncheez to mint is two"
        );
        _;
    }

    modifier canGiftMuncheez(uint256 num) {
        require(
            numGiftedMuncheez + num <= maxGiftedMuncheez,
            "Not enough Muncheez remaining to gift"
        );
        require(
            tokenCounter.current() + num <= maxMuncheez,
            "Not enough Muncheez remaining to mint"
        );
        _;
    }

    

    modifier isValidMerkleProof(bytes32[] calldata merkleProof, bytes32 root) {
        require(
            MerkleProof.verify(
                merkleProof,
                root,
                keccak256(abi.encodePacked(msg.sender))
            ),
            "Address does not exist in list"
        );
        _;
    }

    constructor(
        string memory _baseURI,
        uint256 _maxMuncheez,
        uint256 
    ) 
    ERC721("MuncheezNFT", "MUNCH") 
    {
      baseURI = _baseURI;
      maxMuncheez = _maxMuncheez;
        

    }


//PUBLIC FUNCTIONS FOR MINTING

    function mint(uint256 numberOfTokens)
        external
        payable
        nonReentrant
        isCorrectPayment(NFT_SALE_PRICE, numberOfTokens)
        publicSaleActive
        canMintMuncheez(numberOfTokens)
        maxMuncheezPerWallet(numberOfTokens)
    {
        for (uint256 i = 0; i < numberOfTokens; i++) {
            _safeMint(msg.sender, nextTokenId());
        }
    }

    function mintWhitelistSale(
        uint8 numberOfTokens,
        bytes32[] calldata merkleProof
    )
        external
        payable
        nonReentrant
        whitelistSaleActive
        canMintMuncheez(numberOfTokens)
        isCorrectPayment(NFT_SALE_PRICE, numberOfTokens)
        isValidMerkleProof(merkleProof, whitelistSaleMerkleRoot)
    {
        uint256 numAlreadyMinted = whitelistMintCounts[msg.sender];

        require(
            numAlreadyMinted + numberOfTokens <= MAX_MUNCHEEZ_PER_WALLET,
            "Max Muncheez to mint in whitelist sale is two"
        );

        require(
            tokenCounter.current() + numberOfTokens <= maxWhitelistSaleMuncheez,
            "Not enough Muncheez remaining to mint"
        );

        whitelistMintCounts[msg.sender] = numAlreadyMinted + numberOfTokens;

        for (uint256 i = 0; i < numberOfTokens; i++) {
            _safeMint(msg.sender, nextTokenId());
        }
    }


    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(_exists(tokenId), "Nonexistent token");

        return
            string(abi.encodePacked(baseURI, "/", tokenId.toString(), ".json"));
    }
    //needs fixed re: known Crypto Coven royalty issue
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        require(_exists(tokenId), "Nonexistent token");

        return (address(royaltyReceiverAddress), SafeMath.div(SafeMath.mul(salePrice, 5), 100));
    }

    
//PUBLIC READ ONLY FUNCTIONS

function getBaseURI() external view returns (string memory) {
        return baseURI;
    }

//OWNER ONLY FUNCTIONS

    function setBaseURI(string memory _baseURI) external onlyOwner {
        baseURI = _baseURI;
    }

//Enter true if whitelist sale is active, else enter false
    function setIsWhitelistSaleActive(bool _isWhitelistSaleActive)
        external
        onlyOwner
    {
        isWhitelistSaleActive = _isWhitelistSaleActive;
    }

//Enter true if public sale is active, else enter false
    function setIsPublicSaleActive(bool _isPublicSaleActive)
        external
        onlyOwner
    {
        isPublicSaleActive = _isPublicSaleActive;
    }

//owner can mint the next available token to a specified address
    function safeMint(address to) public onlyOwner {
        uint256 tokenId = tokenCounter.current();
        tokenCounter.increment();
        _safeMint(to, tokenId);
    }

   

//SUPPORTING FUNCTIONS

    function nextTokenId() private returns (uint256) {
        tokenCounter.increment();
        return tokenCounter.current();
    }

    
    // The following functions are overrides required by Solidity.

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, IERC165)
        returns (bool)
    {
        return
            interfaceId == type(IERC2981).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
