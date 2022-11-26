// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "./interfaces/IERC721Receiver.sol";
import "./tokens/ERC721.sol";
import "./tokens/ERC20.sol";
import "./utils/SafeMath.sol";

contract Market is IERC721Receiver {
    ERC20 public erc20;
    ERC721 public erc721;

    bytes4 internal constant MAGIC_ON_ERC721_RECEIVED = 0x150b7a02;

    struct Order {
        address seller;
        uint256 tokenId;
        uint256 price;
    }

    mapping(uint256 => Order) public orderOfId; // token id to order
    Order[] public orders;
    mapping(uint256 => uint256) public idToOrderIndex;

    event Deal(address buyer, address seller, uint256 tokenId, uint256 price);
    event NewOrder(address seller, uint256 tokenId, uint256 price);
    event CancelOrder(address seller, uint256 tokenId);
    event ChangePrice(
        address seller,
        uint256 tokenId,
        uint256 previousPrice,
        uint256 price
    );
// 0x0000000000000000000000000000000000000000000000056BC75E2D63100000 100
// 0x00000000000000000000000000000000000000000000000AD78EBC5AC6200000 200
// 0x00000000000000000000000000000000000000000000000821AB0D4414980000 150
    constructor(ERC20 _erc20, ERC721 _erc721) {
        require(
            address(_erc20) != address(0),
            "Market: ERC20 contract address must be non-null"
        );
        require(
            address(_erc721) != address(0),
            "Market: ERC721 contract address must be non-null"
        );
        erc20 = _erc20;
        erc721 = _erc721;
    }

    function buy(uint256 _tokenId, uint256 _price) external {
        Order storage _order=orderOfId[_tokenId];
        address buyer = msg.sender;
        address seller = _order.seller;
        uint256 price = _order.price;
        require(erc721.ownerOf(_tokenId) == address(this),"NFT not in market" );
        require(_price>=_order.price,"Increase Price");
        erc20.transferFrom(buyer,address(this),_price);
        erc20.transfer(seller,_order.price);
        erc20.transfer(buyer,_price-_order.price);
        erc721.safeTransferFrom(address(this),buyer,_tokenId);
        removeListing(_tokenId);
        emit Deal(buyer, seller, _tokenId, price);
    }

    function cancelOrder(uint256 _tokenId) external {
        Order storage _order = orderOfId[_tokenId];// 此处编写业务逻辑
        address seller =_order.seller;
        require (seller == msg.sender,"Not seller");
        require(erc721.ownerOf(_tokenId) == address(this),"NFT not in market" );
        erc721.safeTransferFrom(address(this),seller,_tokenId);
        removeListing(_tokenId);
        emit CancelOrder(seller, _tokenId);
    }

    function changePrice(uint256 _tokenId, uint256 _price) external {
        require(_price>0, "Price must be greater than zero");// 此处编写业务逻辑
        require(erc721.ownerOf(_tokenId) == address(this),"NFT not in market" );
        Order storage _order = orderOfId[_tokenId];
        address seller =_order.seller;
        require (seller == msg.sender,"Not seller");
        uint256 previousPrice = _order.price;
       _order.price=_price;
        emit ChangePrice(seller, _tokenId, previousPrice, _price);
    }

    function onERC721Received(
        address _operator,
        address _seller,
        uint256 _tokenId,
        bytes calldata _data
    ) public override returns (bytes4) {
        // 此处编写业务逻辑
        placeOrder(_seller,_tokenId,toUint256(_data,0));
        return MAGIC_ON_ERC721_RECEIVED;
    }

    function isListed(uint256 _tokenId) public view returns (bool) {
        return orderOfId[_tokenId].seller != address(0);
    }

    function getOrderLength() public view returns (uint256) {
        return orders.length;
    }

    function placeOrder(
        address _seller,
        uint256 _tokenId,
        uint256 _price
    ) internal {
        //require(erc721.getApproved(_tokenId) == address(this), "Approval Unset");// 此处编写业务逻辑
        require(_price>0, "Price must be greater than zero");
        Order storage _order = orderOfId[_tokenId];
        _order.seller=_seller;
        _order.tokenId=_tokenId;
        _order.price=_price;
        orders.push(_order);
        idToOrderIndex[_tokenId]=orders.length-1;
        //erc721.safeTransferFrom(_seller,address(this),_tokenId);
        emit NewOrder(_seller, _tokenId, _price);
    }

    function removeListing(uint256 _tokenId) public {
         idToOrderIndex[orders[orders.length-1].tokenId]=idToOrderIndex[_tokenId];
         orders[idToOrderIndex[_tokenId]]=orders[orders.length-1];// 此处编写业务逻辑
         orders.pop();
         delete orderOfId[_tokenId];
         delete idToOrderIndex[_tokenId];
    }

    // https://stackoverflow.com/questions/63252057/how-to-use-bytestouint-function-in-solidity-the-one-with-assembly
    function toUint256(bytes memory _bytes, uint256 _start)
        internal
        pure
        returns (uint256)
    {
        require(_start + 32 >= _start, "Market: toUint256_overflow");
        require(_bytes.length >= _start + 32, "Market: toUint256_outOfBounds");
        uint256 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0x20), _start))
        }

        return tempUint;
    }
}
