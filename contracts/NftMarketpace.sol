// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

error NftMarketplace__PriceMustBeAbouveZero();
error NftMarketplace__NotApprovedForMarketplace();
error NftMarketplace__AlreadyListed(address nftAddress, uint256 tokenId);
error NftMarketplace__NotOwner();
error NftMarketplace__NotListed(address nftAddress, uint256 tokenId);
error NftMarketplace__PriceNotMet(address nftAddress, uint256 tokenId, uint256 price);
error NftMarketplace__NoProceeds();
error NftMarketplace__TransferFailed();

contract NftMarketplace is ReentrancyGuard {
  struct Listing {
    uint256 price;
    address seller;
  }

  event ItemListed(
    address indexed seller,
    address indexed nftAddress,
    uint256 indexed tokenId,
    uint256 price
  );

  event ItemBought(
    address indexed buyer,
    address indexed nftAddress,
    uint256 indexed tokenId,
    uint256 price
  );

  event ItemCanceled(address indexed seller, address indexed nftAddress, uint256 indexed tokenId);

  event ItemUpdate(
    address indexed seller,
    address indexed nftAddress,
    uint256 indexed tokenId,
    uint256 newPrice
  );

  //  NFT Contract Address -> NFT TokeId -> Listing
  mapping(address => mapping(uint256 => Listing)) private s_listings;
  // mapping of seller address -> amount earned
  mapping(address => uint) private s_proceeds;

  /////////////////////////////
  /// modifier///
  modifier notListed(
    address nftAddress,
    uint256 tokenId,
    address owner
  ) {
    Listing memory listing = s_listings[nftAddress][tokenId];
    if (listing.price > 0) {
      revert NftMarketplace__AlreadyListed(nftAddress, tokenId);
    }
    _;
  }

  modifier isOwner(
    address nftAddress,
    uint256 tokenId,
    address spender
  ) {
    IERC721 nft = IERC721(nftAddress);
    address owner = nft.ownerOf(tokenId);
    if (spender != owner) {
      revert NftMarketplace__NotOwner();
    }
    _;
  }

  modifier isListed(address nftAddress, uint256 tokenId) {
    Listing memory listing = s_listings[nftAddress][tokenId];
    if (listing.price <= 0) {
      revert NftMarketplace__NotListed(nftAddress, tokenId);
    }
    _;
  }

  ///////////////////////
  /// Main functions/////
  ///////////////////////
  /*
   * @notice Method for listing NFT
   * @param nftAddress Address of NFT contract
   * @param tokenId Token ID of NFT
   * @param price sale price for each item
   */

  function listItem(
    address nftAddress,
    uint256 tokenId,
    uint256 price
  ) external notListed(nftAddress, tokenId, msg.sender) isOwner(nftAddress, tokenId, msg.sender) {
    if (price <= 0) {
      revert NftMarketplace__PriceMustBeAbouveZero();
    }

    // owners can stil hold thier NFTs, and give marketplace approval to sell the NFT for them

    IERC721 nft = IERC721(nftAddress);
    if (nft.getApproved(tokenId) != address(this)) {
      revert NftMarketplace__NotApprovedForMarketplace();
    }
    s_listings[nftAddress][tokenId] = Listing(price, msg.sender);
    emit ItemListed(msg.sender, nftAddress, tokenId, price);
  }

  function buyItem(
    address nftAddress,
    uint256 tokenId
  ) external payable nonReentrant isListed(nftAddress, tokenId) {
    Listing memory listingItem = s_listings[nftAddress][tokenId];
    if (msg.value < listingItem.price) {
      revert NftMarketplace__PriceNotMet(nftAddress, tokenId, listingItem.price);
    }
    s_proceeds[listingItem.seller] = s_proceeds[listingItem.seller] + msg.value;
    delete (s_listings[nftAddress][tokenId]);
    IERC721(nftAddress).safeTransferFrom(listingItem.seller, msg.sender, tokenId);
    // check to make sure the NFT was Transfered
    emit ItemBought(msg.sender, nftAddress, tokenId, listingItem.price);
  }

  function cancelListing(
    address nftAddress,
    uint256 tokenId
  ) external isOwner(nftAddress, tokenId, msg.sender) isListed(nftAddress, tokenId) {
    delete (s_listings[nftAddress][tokenId]);
    emit ItemCanceled(msg.sender, nftAddress, tokenId);
  }

  function updateListing(
    address nftAddress,
    uint256 tokenId,
    uint256 newPrice
  ) external isListed(nftAddress, tokenId) isOwner(nftAddress, tokenId, msg.sender) {
    if (newPrice <= 0) {
      revert NftMarketplace__PriceMustBeAbouveZero();
    }
    s_listings[nftAddress][tokenId].price = newPrice;
    emit ItemUpdate(msg.sender, nftAddress, tokenId, newPrice);
  }

  function withdrawProceeds() external {
    uint256 proceeds = s_proceeds[msg.sender];
    if (proceeds <= 0) {
      revert NftMarketplace__NoProceeds();
    }
    s_proceeds[msg.sender] = 0;
    (bool success, ) = payable(msg.sender).call{value: proceeds}("");
    if (!success) {
      revert NftMarketplace__TransferFailed();
    }
  }

  ///////////////////////
  /// getter functions///
  ///////////////////////

  function getListing(address nftAddress, uint256 tokenId) external view returns (Listing memory) {
    return s_listings[nftAddress][tokenId];
  }

  function getProceeds(address seller) external view returns (uint256) {
    return s_proceeds[seller];
  }
}
// 1. Crate a decentralized NFT Marketplace
// 1. `listItem`: List NFTs on the marketplace
// 2. `buyItem`: buy the NFTs
// 3. `cancelItem`: Cancel a listing
// 4. `updateListing`: Update price
// 5. `withdrawProceeds`: withdraw payment for my bought NFTs
