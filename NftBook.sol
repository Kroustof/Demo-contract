// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";


contract NftBook is 
    ERC1155, 
    Ownable, 
    ERC1155Burnable, 
    ERC1155Supply 
{
    
    // ! =============== COLLECTION VARIABLES =============== ! //

    uint256 private BOOK_IDS;

    string public name;
    string public CONTRACT_URI;

    // ! =============== PUBLIRARE MINT CUT SETTINGS =============== ! //
    
    uint16 public CUT_IN_BIPS; // 1% equal 100
    address public CUT_RECEIVER;

    // ? =============== STRUCTURES =============== ? //

    struct Royalty {
        address royaltyReceiver;
        uint16 royaltyFeesInBips;
    }

    // ? =============== MAPPING =============== ? //

    mapping(uint256 => uint256) private MAX_COPIES;
    mapping(uint256 => string) private BOOK_URIS;
    mapping(uint256 => Royalty) private ROYALTIES;
    
    // ? =============== EVENTS =============== ? //

    event NewBookMinted(address indexed from, address indexed to, uint256 indexed id, uint256 amount, uint256 maxCopies);
    event MoreCopyMinted(address indexed from, address indexed to, uint256 indexed id, uint256 amount);

    // ! =============== INITIALISATION =============== ! //

    constructor(
        address initialOwner, 
        uint256 amount, 
        uint256 maxCopies, 
        string memory bookURI, 
        uint16 royaltyFeesInBips, 
        string memory contractUri, 
        string memory contractName, 
        address cutReceiver, 
        uint16 cutInBips
    ) 
        ERC1155("") 
        Ownable(initialOwner)
    {
        if (amount > maxCopies) {
            MAX_COPIES[0] = amount;  
        } else {
            MAX_COPIES[0] = maxCopies;
        }
        BOOK_URIS[0] = bookURI;
        ROYALTIES[0] = Royalty({royaltyReceiver: initialOwner, royaltyFeesInBips: royaltyFeesInBips});
        CONTRACT_URI = contractUri;
        name = contractName;
        CUT_IN_BIPS = cutInBips;
        CUT_RECEIVER = cutReceiver;
        BOOK_IDS++;
        _mint(cutReceiver, 0, calculateCut(maxCopies), "");
        _mint(initialOwner, 0, (amount - calculateCut(maxCopies)), "");

        emit NewBookMinted(msg.sender, initialOwner, 0, amount, MAX_COPIES[0]);
    }

    // ? =============== FUNCTION GET NFT BOOK URI =============== ? //

    function uri(uint256 _id) 
        public view 
        override 
        returns (string memory) 
    {
        return (BOOK_URIS[_id]);
    }

    // ? =============== FUNCTION GET COLLECTION URI =============== ? //

    function contractURI() 
        public view 
        returns (string memory) 
    {
        return CONTRACT_URI;
    }

    // ? =============== FUNCTION UPDATE NFT BOOK URI =============== ? //

    function setBookUri(uint256 _id, string memory _uri) 
        public 
        onlyOwner 
    {
        BOOK_URIS[_id] = _uri;
    }

    // ? =============== FUNCTION GET NFT BOOK MAX COPIES =============== ? //

    function getMaxCopies(uint256 _id) 
        public view 
        returns (uint256) 
    {
        return (MAX_COPIES[_id]);
    }

    // ? =============== FUNCTION MINT NEW NFT BOOK =============== ? //

    function mintNewBook(address to, uint256 amount, uint256 maxCopies, string memory _uri, uint16 _royaltyFeesInBips) 
        public 
        onlyOwner 
    {
        require(amount <= maxCopies, "Amount cant exceed copies limit");
        uint256 newBookId = BOOK_IDS;
        MAX_COPIES[newBookId] = maxCopies;
        BOOK_URIS[newBookId] = _uri;
        ROYALTIES[newBookId] = Royalty({royaltyReceiver: msg.sender, royaltyFeesInBips: _royaltyFeesInBips});
        BOOK_IDS++;
        _mint(CUT_RECEIVER, newBookId, calculateCut(maxCopies), "");
        _mint(to, newBookId, (amount - calculateCut(maxCopies)), "");

        emit NewBookMinted(msg.sender, to, newBookId, amount, maxCopies);
    }
    
    // ? =============== FUNCTION MINT MORE COPIES =============== ? //

    function mintBook(address to, uint256 _id, uint256 amount) 
        public 
        onlyOwner 
    {
        uint256 newTotalCopies = totalSupply(_id) + amount;
        require(newTotalCopies <= MAX_COPIES[_id], "Maximum copies limit reached");
        _mint(to, _id, amount, "");

        emit MoreCopyMinted(msg.sender, to, _id, amount);
    }

    // ? =============== FUNCTION MINT MORE COPIES OF MULTIPLE NFT BOOKS =============== ? //

    function mintBookBatch(address to, uint256[] memory _ids, uint256[] memory amounts) 
        public 
        onlyOwner 
    {
        uint256 newTotalCopies;
        for (uint256 i = 0; i < _ids.length; i++) {
            newTotalCopies = totalSupply(_ids[i]) + amounts[i];
            require(newTotalCopies <= MAX_COPIES[_ids[i]], "One or more copies limit reached");
        }
        _mintBatch(to, _ids, amounts, "");
    }

    // ? =============== CALCULATE PUBLIRARE CUT =============== ? //

    function calculateCut(uint256 amount) 
        internal view
        returns (uint256)
    {
        if (CUT_IN_BIPS > 0) {
            uint256 cut = amount * CUT_IN_BIPS / 10000;
            if (amount <= 10) {
            return 0;
            } else if(cut <= 1) {
            return 1;
            } else {
            return cut;
            }
        } else {
            return 0;
        }
    }

    // ! =============== UPDATE CUT VALUE =============== ! //

    function setCutInBips(uint16 cutInBips)
        public
    {
        require(msg.sender == CUT_RECEIVER, "Unauthorized, only cut receiver can change this value.");
        require(cutInBips <= 1000, "Cannot set a cut greater than 10%.");
        CUT_IN_BIPS = cutInBips;
    }

    // ! =============== UPDATE CUT RECEIVER =============== ! //

    function setCutReceiver(address cutReceiver)
        public
    {
        require(msg.sender == CUT_RECEIVER, "Unauthorized, only cut receiver can change this address.");
        CUT_RECEIVER = cutReceiver;
    }

    // ! =============== INTERFACE SUPPORT FOR ROYALTIES =============== ! //

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155)
        returns (bool)
    {
        return interfaceId == 0x2a55205a || super.supportsInterface(interfaceId);
    }

    // ? =============== FUNCTION GET ROYALTY INFO =============== ? //

    function royaltyInfo(uint256 _id, uint256 salePrice) 
        external view 
        returns (address receiver, uint256 royaltyAmount) 
    {
        return (ROYALTIES[_id].royaltyReceiver, calculateRoyalty(_id, salePrice));
    } 

    // ? =============== FUNCTION CALCULATE ROYALTY FEE =============== ? //

    function calculateRoyalty(uint256 _id, uint256 salePrice) 
        public view 
        returns (uint256) 
    {
        return salePrice * ROYALTIES[_id].royaltyFeesInBips / 10000;
    }

    // ! =============== FUNCTION UPDATE ROYALTY INFO =============== ! //

    function setRoyaltyInfo(uint256 _id, address receiver, uint16 royaltyFeesInBips) 
        public 
        onlyOwner 
    {
        ROYALTIES[_id].royaltyReceiver = receiver;
        ROYALTIES[_id].royaltyFeesInBips = royaltyFeesInBips;
    }

    // ! =============== FUNCTION UPDATE COLLECTION URI =============== ! //

    function setContractURI(string calldata contractUri) 
        public 
        onlyOwner 
    {
        CONTRACT_URI = contractUri;
    }

    // ! =============== FUNCTION UPDATE COLLECTION NAME =============== ! //

    function setContractName(string memory _name) 
        public 
        onlyOwner 
    {
        name = _name;
    }

    // ? =============== OVERRIDE CONFLICT FUNCTIONS =============== ? //

    // The following functions are overrides required by Solidity.
    function _update(address from, address to, uint256[] memory ids, uint256[] memory values)
        internal
        override(ERC1155, ERC1155Supply)
    {
        super._update(from, to, ids, values);
    }

    function isApprovedForAll(
        address _owner,
        address _operator
    ) public override view returns (bool isOperator) {
        // if OpenSea's ERC1155 Proxy Address is detected, auto-return true
       if (_operator == address(0x80c4aa5FA20dAcb1D8eB7992Eda79C4A526c0f2c)) {
            return true;
        }
        // if PubliRare's ERC1155 Proxy Address is detected, auto-return true
       if (_operator == address(0x2Da7245FbA0af5C9E4c89873A2E5d7134b5dBa90)) {
            return true;
        }
        // otherwise, use the default ERC1155.isApprovedForAll()
        return ERC1155.isApprovedForAll(_owner, _operator);
    }

}
