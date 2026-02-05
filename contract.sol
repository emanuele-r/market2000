// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

contract ProductsOptimized {

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error OnlyOwner();
    error InvalidProduct();
    error NotSeller();
    error InvalidQuantity();
    error InvalidPrice();
    error NotSellable();
    error InsufficientStock();
    error SelfBuy();
    error IncorrectETH();
    error WithdrawalFailed();
    error TransferFailed();

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    address public immutable owner;
    uint256 public transactionFee;

    struct Product {
        address seller;      // 20 bytes
        uint96 price;        // 12 bytes
        uint32 quantity;     // 4 bytes
        uint32 initialQty;   // 4 bytes
        bool sellable;       // 1 byte
        bytes32 name;        // 32 bytes
    }

    Product[] public products;
    mapping(address => uint256[]) private sellerProducts;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event ProductCreated(bytes32 indexed name, uint256 quantity, uint256 price, address indexed seller);
    event ProductUpdated(uint256 indexed productId, bytes32 name, uint256 quantity, uint256 price);
    event ProductCancelled(uint256 indexed productId);
    event ProductSold(bytes32 indexed name, uint256 quantity, uint256 price, address indexed seller, address indexed buyer);
    event TransactionFeeUpdated(uint256 oldFee, uint256 newFee);
    event FundsWithdrawn(address indexed owner, uint256 amount, bytes32 motivation);

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    constructor() {
        owner = msg.sender;
        transactionFee = 100_000;
    }

    /*//////////////////////////////////////////////////////////////
                            PRODUCT LOGIC
    //////////////////////////////////////////////////////////////*/

    function create_product(
        bytes32 name,
        uint32 quantity,
        uint96 price
    ) external {
        if (quantity == 0) revert InvalidQuantity();
        if (price == 0) revert InvalidPrice();

        products.push(
            Product({
                seller: msg.sender,
                price: price,
                quantity: quantity,
                initialQty: quantity,
                sellable: true,
                name: name
            })
        );

        sellerProducts[msg.sender].push(products.length - 1);

        emit ProductCreated(name, quantity, price, msg.sender);
    }

    function updateProduct(
        uint256 index,
        bytes32 newName,
        uint32 newQuantity,
        uint96 newPrice
    ) external {
        if (index >= products.length) revert InvalidProduct();

        Product storage p = products[index];

        if (msg.sender != p.seller) revert NotSeller();
        if (p.initialQty != p.quantity) revert NotSellable();
        if (newQuantity == 0) revert InvalidQuantity();
        if (newPrice == 0) revert InvalidPrice();

        p.name = newName;
        p.quantity = newQuantity;
        p.initialQty = newQuantity;
        p.price = newPrice;

        emit ProductUpdated(index, newName, newQuantity, newPrice);
    }

    function cancelListing(uint256 index) external {
        if (index >= products.length) revert InvalidProduct();

        Product storage p = products[index];

        if (msg.sender != p.seller) revert NotSeller();
        if (!p.sellable) revert NotSellable();

        p.sellable = false;

        emit ProductCancelled(index);
    }

    function reactivateListing(uint256 index) external {
        if (index >= products.length) revert InvalidProduct();

        Product storage p = products[index];

        if (msg.sender != p.seller) revert NotSeller();
        if (p.quantity == 0) revert InvalidQuantity();

        p.sellable = true;

        emit ProductUpdated(index, p.name, p.quantity, p.price);
    }

    function buyProduct(uint256 index, uint32 quantity) external payable {
        if (index >= products.length) revert InvalidProduct();

        Product storage p = products[index];

        if (!p.sellable) revert NotSellable();
        if (quantity == 0) revert InvalidQuantity();
        if (p.quantity < quantity) revert InsufficientStock();
        if (msg.sender == p.seller) revert SelfBuy();

        uint256 totalPrice = uint256(p.price) * quantity;
        uint256 totalFee   = transactionFee * quantity;

        if (msg.value != totalPrice + totalFee) revert IncorrectETH();

        unchecked {
            p.quantity -= quantity;
        }

        if (p.quantity == 0) p.sellable = false;

        (bool ok,) = p.seller.call{value: totalPrice}("");
        if (!ok) revert TransferFailed();

        emit ProductSold(p.name, quantity, p.price, p.seller, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function updateTransactionFee(uint256 newFee) external onlyOwner {
        uint256 old = transactionFee;
        transactionFee = newFee;
        emit TransactionFeeUpdated(old, newFee);
    }

    function requestFund(uint256 amount, bytes32 motivation) external onlyOwner {
        if (amount == 0 || amount > address(this).balance) revert WithdrawalFailed();

        (bool ok,) = owner.call{value: amount}("");
        if (!ok) revert WithdrawalFailed();

        emit FundsWithdrawn(owner, amount, motivation);
    }

    /*//////////////////////////////////////////////////////////////
                                VIEWS
    //////////////////////////////////////////////////////////////*/

    function getProduct(uint256 index)
        external
        view
        returns (bytes32, uint256, uint256, bool, address)
    {
        if (index >= products.length) revert InvalidProduct();
        Product storage p = products[index];
        return (p.name, p.quantity, p.price, p.sellable, p.seller);
    }

    function getProductsBySeller(address seller)
        external
        view
        returns (Product[] memory arr)
    {
        uint256[] storage ids = sellerProducts[seller];
        uint256 len = ids.length;

        arr = new Product[](len);

        for (uint256 i; i < len; ++i) {
            arr[i] = products[ids[i]];
        }
    }

    function totalProducts() external view returns (uint256) {
        return products.length;
    }

    function itemSold(uint256 index) external view returns (uint256) {
        if (index >= products.length) revert InvalidProduct();
        Product storage p = products[index];
        return p.initialQty - p.quantity;
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
