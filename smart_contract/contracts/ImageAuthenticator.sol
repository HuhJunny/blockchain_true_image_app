// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract ImageAuthenticator is ReentrancyGuard {
    struct ImageData {
        string pHash;
    }

    mapping(string => ImageData) private images;
    mapping(string => address) private imageOwners;
    mapping(string => uint256) private imagePrices;

    event ImageRegistered(
        address indexed owner,
        string pHash,
        uint256 price,
        uint256 timestamp
    );
    event ImagePriceUpdated(
        address indexed owner,
        string pHash,
        uint256 oldPrice,
        uint256 newPrice,
        uint256 timestamp
    );
    event ImagePurchased(
        address indexed buyer,
        address indexed owner,
        string pHash,
        uint256 amount,
        uint256 timestamp
    );

    error EmptyPHash();
    error InvalidPrice();
    error ImageAlreadyRegistered();
    error ImageNotRegistered();
    error NotImageOwner();
    error IncorrectPayment(uint256 expected, uint256 received);
    error OwnerCannotPurchaseOwnImage();
    error PaymentTransferFailed();

    modifier onlyRegistered(string memory pHash) {
        if (!_isRegistered(pHash)) {
            revert ImageNotRegistered();
        }
        _;
    }

    modifier onlyImageOwner(string memory pHash) {
        if (imageOwners[pHash] != msg.sender) {
            revert NotImageOwner();
        }
        _;
    }

    function registerImage(
        string calldata pHash,
        uint256 price
    ) external {
        if (bytes(pHash).length == 0) {
            revert EmptyPHash();
        }
        if (price == 0) {
            revert InvalidPrice();
        }
        if (_isRegistered(pHash)) {
            revert ImageAlreadyRegistered();
        }

        images[pHash] = ImageData({pHash: pHash});
        imageOwners[pHash] = msg.sender;
        imagePrices[pHash] = price;

        emit ImageRegistered(msg.sender, pHash, price, block.timestamp);
    }

    function updatePrice(
        string calldata pHash,
        uint256 newPrice
    ) external onlyRegistered(pHash) onlyImageOwner(pHash) {
        if (newPrice == 0) {
            revert InvalidPrice();
        }

        uint256 oldPrice = imagePrices[pHash];
        imagePrices[pHash] = newPrice;

        emit ImagePriceUpdated(
            msg.sender,
            pHash,
            oldPrice,
            newPrice,
            block.timestamp
        );
    }

    function purchaseImage(
        string calldata pHash
    ) external payable nonReentrant onlyRegistered(pHash) {
        address owner = imageOwners[pHash];
        uint256 price = imagePrices[pHash];

        if (msg.sender == owner) {
            revert OwnerCannotPurchaseOwnImage();
        }
        if (msg.value != price) {
            revert IncorrectPayment(price, msg.value);
        }

        (bool success, ) = payable(owner).call{value: msg.value}("");
        if (!success) {
            revert PaymentTransferFailed();
        }

        emit ImagePurchased(
            msg.sender,
            owner,
            pHash,
            msg.value,
            block.timestamp
        );
    }

    function getImage(
        string calldata pHash
    )
        external
        view
        onlyRegistered(pHash)
        returns (address owner, uint256 price)
    {
        return (imageOwners[pHash], imagePrices[pHash]);
    }

    function getImageData(
        string calldata pHash
    ) external view onlyRegistered(pHash) returns (ImageData memory) {
        return images[pHash];
    }

    function getOwner(
        string calldata pHash
    ) external view onlyRegistered(pHash) returns (address) {
        return imageOwners[pHash];
    }

    function getPrice(
        string calldata pHash
    ) external view onlyRegistered(pHash) returns (uint256) {
        return imagePrices[pHash];
    }

    function isRegistered(string calldata pHash) external view returns (bool) {
        return _isRegistered(pHash);
    }

    function _isRegistered(string memory pHash) private view returns (bool) {
        return bytes(images[pHash].pHash).length != 0;
    }
}
