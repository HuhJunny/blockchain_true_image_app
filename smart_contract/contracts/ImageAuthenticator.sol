// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract ImageAuthenticator is ReentrancyGuard {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    struct ImageData {
        string pHash;
    }

    bytes32 private constant REGISTER_ACTION = keccak256("REGISTER_IMAGE");
    bytes32 private constant UPDATE_PRICE_ACTION = keccak256("UPDATE_PRICE");
    bytes32 private constant PURCHASE_ACTION = keccak256("PURCHASE_IMAGE");

    address public immutable backendSigner;

    mapping(string => ImageData) private images;
    mapping(string => address) private imageOwners;
    mapping(string => uint256) private imagePrices;
    mapping(bytes32 => bool) private usedApprovals;

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
    event BackendApprovalUsed(
        bytes32 indexed approvalHash,
        address indexed actor,
        bytes32 indexed action,
        uint256 nonce
    );

    error EmptyPHash();
    error InvalidPrice();
    error InvalidBackendSigner();
    error InvalidBackendApproval();
    error BackendApprovalExpired();
    error BackendApprovalAlreadyUsed();
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

    constructor(address backendSigner_) {
        if (backendSigner_ == address(0)) {
            revert InvalidBackendSigner();
        }
        backendSigner = backendSigner_;
    }

    function registerImage(
        string calldata pHash,
        uint256 price,
        uint256 nonce,
        uint256 deadline,
        bytes calldata backendSignature
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
        _consumeBackendApproval(
            REGISTER_ACTION,
            msg.sender,
            pHash,
            price,
            nonce,
            deadline,
            backendSignature
        );

        images[pHash] = ImageData({pHash: pHash});
        imageOwners[pHash] = msg.sender;
        imagePrices[pHash] = price;

        emit ImageRegistered(msg.sender, pHash, price, block.timestamp);
    }

    function updatePrice(
        string calldata pHash,
        uint256 newPrice,
        uint256 nonce,
        uint256 deadline,
        bytes calldata backendSignature
    ) external onlyRegistered(pHash) onlyImageOwner(pHash) {
        if (newPrice == 0) {
            revert InvalidPrice();
        }
        _consumeBackendApproval(
            UPDATE_PRICE_ACTION,
            msg.sender,
            pHash,
            newPrice,
            nonce,
            deadline,
            backendSignature
        );

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
        string calldata pHash,
        uint256 price,
        uint256 nonce,
        uint256 deadline,
        bytes calldata backendSignature
    ) external payable nonReentrant onlyRegistered(pHash) {
        address owner = imageOwners[pHash];
        uint256 currentPrice = imagePrices[pHash];

        if (msg.sender == owner) {
            revert OwnerCannotPurchaseOwnImage();
        }
        if (currentPrice != price || msg.value != price) {
            revert IncorrectPayment(currentPrice, msg.value);
        }
        _consumeBackendApproval(
            PURCHASE_ACTION,
            msg.sender,
            pHash,
            price,
            nonce,
            deadline,
            backendSignature
        );

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

    function getApprovalHash(
        bytes32 action,
        address actor,
        string calldata pHash,
        uint256 price,
        uint256 nonce,
        uint256 deadline
    ) external view returns (bytes32) {
        return _approvalHash(action, actor, pHash, price, nonce, deadline);
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

    function _consumeBackendApproval(
        bytes32 action,
        address actor,
        string calldata pHash,
        uint256 price,
        uint256 nonce,
        uint256 deadline,
        bytes calldata backendSignature
    ) private {
        if (block.timestamp > deadline) {
            revert BackendApprovalExpired();
        }

        bytes32 approvalHash = _approvalHash(
            action,
            actor,
            pHash,
            price,
            nonce,
            deadline
        );
        if (usedApprovals[approvalHash]) {
            revert BackendApprovalAlreadyUsed();
        }

        address recovered = approvalHash
            .toEthSignedMessageHash()
            .recover(backendSignature);
        if (recovered != backendSigner) {
            revert InvalidBackendApproval();
        }

        usedApprovals[approvalHash] = true;
        emit BackendApprovalUsed(approvalHash, actor, action, nonce);
    }

    function _approvalHash(
        bytes32 action,
        address actor,
        string calldata pHash,
        uint256 price,
        uint256 nonce,
        uint256 deadline
    ) private view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    block.chainid,
                    address(this),
                    action,
                    actor,
                    keccak256(bytes(pHash)),
                    price,
                    nonce,
                    deadline
                )
            );
    }

    function _isRegistered(string memory pHash) private view returns (bool) {
        return bytes(images[pHash].pHash).length != 0;
    }
}
