// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/*With thanks to @nftchance, @masonnft, and @nuclearnerds for all of
the resources they share with developers. This contract draws
on concepts from Nuclear Nerds and Chance's Medium articles*/

//imports
import "./IERC721.sol";
import "./IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ERC721Enumerable.sol";
import "./extensions/IERC721Metadata.sol";
import "../../utils/Address.sol";
import "../../utils/Context.sol";
import "../../utils/Strings.sol";
import "../../utils/introspection/ERC165.sol";

contract FluffyNFT is Context, ERC165, IERC721, ERC721Enumerable, Ownable, IERC721Metadata {
    using Address for address;
    using Strings for uint256;

    //state variables
    string public               baseURI;
    address public immutable    proxyRegistryAddress; 
    uint256 public              MAX_SUPPLY;
    uint256 public constant     MAX_PER_TX          = 3;
    uint256 public constant     RESERVES            = 111;
    uint256 public constant     priceInWei          = 0.05 ether;

    //constructor
    constructor(string memory _baseURI,
                address _proxyRegistryAddress,

    ) 
        ERC721("Fluffy Friends", "FLUFF")
    {
        _baseURI = baseURI;
        /*The OpenSea Proxy Registry addresses are:
Rinkeby: 0xf57b2c51ded3a29e6891aba85459d600256cf317
Mainnet: 0xa5409ec958c83c3f309868babaca7c86dcb077c1*/
        _proxyRegistryAddress = proxyRegistryAddress;



    //events

    //required for ERC721 specs

    //emits with any change in NFT ownership
    event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);
    //emits when approved address for an NFT is modified
    event Approval(address indexed _owner, address indexed _approved, uint256 indexed _tokenId);
    //emits when operator is enabled/disabled for an owner to manage all NFTs for the owner
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);
    



    //modifiers

    //onlyOwner functions

    //when whitelist mint is over, call this function and pass desired max supply of NFTs (highest possible token ID)
    function togglePublicSale(uint256 _MAX_SUPPLY) external onlyOwner {
        delete whitelistMerkleRoot;
        MAX_SUPPLY = _MAX_SUPPLY;

    //allow collection of reserved NFTs by owner/team
    function collectReserves() external onlyOwner {
        require(_owners.length == 0, 'Reserves already taken.');
        for(uint256 i; i < RESERVES; i++)
            _mint(_msgSender(), i);

    //set base URI --> ipfs://<hash>
    function setBaseURI(string memory _baseURI) public onlyOwner {
        baseURI = _baseURI;
    }


    //functions

    function publicMint(uint256 count) public payable {
        uint256 totalSupply = _owners.length;
        require(totalSupply + count < MAX_SUPPLY, "Excedes max supply.");
        require(count < MAX_PER_TX, "Exceeds max per transaction.");
        require(count * priceInWei == msg.value, "Invalid funds provided.");
    
        for(uint i; i < count; i++) { 
            _mint(_msgSender(), totalSupply + i);
        }
    }

    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        require(_exists(_tokenId), "Token does not exist.");
        return string(abi.encodePacked(baseURI, Strings.toString(_tokenId)));
    }



    //required for ERC-721 standard

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        (_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");

        _transfer(from, to, tokenId);
    }
    
    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
    }


    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        _safeTransfer(from, to, tokenId, _data);
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");

        _transfer(from, to, tokenId);
    }

    function setApprovalForAll(address operator, bool approved) public virtual override {
        _setApprovalForAll(_msgSender(), operator, approved);

    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        require(_exists(tokenId), "ERC721: approved query for nonexistent token");

        return _tokenApprovals[tokenId];
    }
    
    function approve(address to, uint256 tokenId) public virtual override {
        address owner = ERC721.ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");

        require(
            _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not owner nor approved for all"
        );

        _approve(to, tokenId);
    }
    
    function balanceOf(address owner) public view virtual override returns (uint256) {
        require(owner != address(0), "ERC721: balance query for the zero address");
        return _balances[owner];

    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "ERC721: owner query for nonexistent token");
        return owner;

    //required to interact with imported interfaces
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
}


contract OwnableDelegateProxy { }
contract OpenSeaProxyRegistry {
    mapping(address => OwnableDelegateProxy) public proxies;
    mapping(address => bool) proxyToApproved;
}   

//allows holders to list on OpenSea with no gas fees
    function isApprovedForAll(address _owner, address operator) public view override
returns (bool) {
    OpenSeaProxyRegistry proxyRegistry = OpenSeaProxyRegistry(proxyRegistryAddress);
    if (address(proxyRegistry.proxies(_owner)) == operator) return true;
    return super.isApprovedForAll(_owner, operator);
}
//allows gasless future collection approval for cross-collection interaciton
    function flipProxyState(address proxyAddress) public onlyOwner {
        proxyToApproved[proxyAddress] =!proxyToApproved[proxyAddress];
    }