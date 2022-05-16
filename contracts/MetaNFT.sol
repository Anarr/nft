//Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract MetaNFT is ERC721Enumerable, Ownable  {

    IERC20Upgradeable meto;
    IERC20Upgradeable usdt;

    //keep sale source info.
    enum SALE_FROM {PRIVATE, LAUNCHPAD, WHITELIST}

    struct OptionLaunchpadLand{
        uint ClaimableCount;
        uint ClaimedCount;
    }

    //keeps user minted nfts ids
    mapping(address => uint256[]) public collection;

    //keep disabled lands ids
    uint256[] public disabledLands;

    //keep investors lands. These lands do not require payment.
    mapping(uint256 => address) public privateSaleLands;

    //keep whitelist users list. Whitelist users can buy nfts earlier than others.
    mapping(address => bool) whiteListAddresses;
    mapping(address => OptionLaunchpadLand) public launchpadLands;

    // use as the index if item not found in array
    uint256 private ID_NOT_FOUND = 9999999999999999;
    // argument with the ID_SKIP_VALUE block all transaction on it.
    uint256 private ID_SKIP_VALUE = 9999999999999999;

    uint256 public LAND_PRICE_METO = 1000000000000000;
    uint256 public LAND_PRICE_USDT = 100;
    uint256 public WHITELIST_PRICE_METO = 1000000000000000;
    uint256 public WHITELIST_PRICE_USDT = 50;

    //keep land max tid (technical id)
    uint256 TID_MAX_INTERVAL = 24000;

    //kep plot min tid (technical_id)
    uint256 TID_MIN_INTERVAL = 1;
 
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
        
    string public baseTokenURI;
    bool private launchpadSaleStatus;
    bool private whiteListSaleStatus;
    bool private privateSaleStatus;
    bool private publicSaleStatus;

    event Mint(address indexed _from, uint256 tokenId, uint256 _price);
    event MultipleMint(address indexed _from, uint256[] tokenIds, uint256 _price);
    event Claim(address indexed _from, uint256 _tid, uint256 claimableCount, uint256 claimedCount);

    modifier Mintable(uint256 _tid) {
        require(_tid <= TID_MAX_INTERVAL && _tid >= TID_MIN_INTERVAL, "Invalid tid.");
        require(!isDisabledLand(_tid), "The given tid is inside disabledLands.");
        require(_isSaleOpened(_tid), "The sale not opened yet.");
        _;
    }
    modifier Claimable () {
        require(launchpadSaleStatus, "Launchad sale not opened yet.");
        _;
    }

    constructor() ERC721("MyNFT", "NFT") {
        meto = IERC20Upgradeable(0xc39A5f634CC86a84147f29a68253FE3a34CDEc57);
        usdt = IERC20Upgradeable(0x337610d27c682E347C9cD60BD4b3b107C9d34dDd);
        setBaseURI("ipfs://QmeYyiEmYhGmEuMU8q9uMs7Uprs7KGdEiKBwRpSsoapn2K/");
    }

    /* Start of Administrative Functions */
    function setLandPriceWithMeto(uint256 _price, uint256 _whiteListPrice) public onlyOwner 
    {   
        if (_price != ID_SKIP_VALUE || _price == LAND_PRICE_METO) {
            LAND_PRICE_METO = _price;
        }
        if ( _whiteListPrice != ID_SKIP_VALUE || _whiteListPrice == WHITELIST_PRICE_METO) {
            WHITELIST_PRICE_METO = _whiteListPrice;
        }
    }

    function setTIDMaxInterval(uint256 v) public onlyOwner
    {
        TID_MAX_INTERVAL = v;
    }

    function setTIDMinInterval(uint256 v) public onlyOwner
    {
        TID_MIN_INTERVAL = v;
    }

    function withdraw(address payable addr, uint256 _amount) external onlyOwner {
        SafeERC20Upgradeable.safeTransfer(meto, addr, _amount);
    }

    function withdrawUSDT(address payable addr, uint256 _amount) external onlyOwner {
        SafeERC20Upgradeable.safeTransfer(usdt, addr, _amount);
    }

    function setLandAsDisabled(uint256[] memory _tids) public onlyOwner 
    {
        for (uint i = 0; i < _tids.length; i++) {
            disabledLands.push(_tids[i]);
        }
    }

    function removeDisableLand(uint256 _tid) public onlyOwner 
    {
        uint256 _index = getDisabledLandIndex(_tid);
        require(_index != ID_NOT_FOUND, "index out of bound.");

        for (uint i = _index; i < disabledLands.length - 1; i++) {
            disabledLands[i] = disabledLands[i + 1];
        }

        disabledLands.pop();
    }

    function getDisabledLandIndex(uint256 _tid) private view returns(uint256)
    {
        for (uint256 i = 0; i < disabledLands.length; i++) {
            if (disabledLands[i] == _tid) {
                return i;
            }
        }

        return ID_NOT_FOUND;
    }

    function setLaunchpadLand(address _owner, OptionLaunchpadLand memory _option) public onlyOwner
    {
        launchpadLands[_owner] = _option;
    }
    
    function _baseURI() internal 
                    view 
                    virtual 
                    override 
                    returns (string memory) {
         return baseTokenURI;
    }
    
    function setBaseURI(string memory _baseTokenURI) public onlyOwner {
        baseTokenURI = _baseTokenURI;
    }

    function setSaleStatus(bool _privateSaleStatus, bool _launchpadSaleStatus, bool _publicSaleStatus, bool _whiteListSaleStatus) public onlyOwner
    {
        privateSaleStatus = _privateSaleStatus;
        launchpadSaleStatus = _launchpadSaleStatus;
        publicSaleStatus = _publicSaleStatus;
        whiteListSaleStatus = _whiteListSaleStatus;
    }

    /* End of Administrative Functions */

    // return user nft collection 
    function myCollection() public view returns(uint256[] memory)
    {
        return collection[msg.sender];
    }

    // mint mint single or multiple nft
    function mintWithMeto(uint256 _tid)
        public Mintable(_tid)
        returns (uint256)
    {

        require(meto.balanceOf(msg.sender) > LAND_PRICE_METO, "User has not enough balance for this nft.");

        //check _tid not belongs to privateSaleLands then first make payment
        if (privateSaleLands[_tid] != msg.sender) {
            SafeERC20Upgradeable.safeTransferFrom(meto, msg.sender, address(this), LAND_PRICE_METO);
        }
        _safeMint(msg.sender, _tid);
        //insert minted nft to user collection
        collection[msg.sender].push(_tid);
        emit Mint(msg.sender, _tid, LAND_PRICE_METO);
        return _tid;
    }

    // mint multiple nfts with meto
    function mintMultipleNftWithMeto(uint256[] memory _ids) public 
    {
        require(_ids.length > 0, "_ids size can not be zero.");
        uint256 totalPrice = LAND_PRICE_METO * _ids.length;
        require(meto.balanceOf(msg.sender) > LAND_PRICE_METO * _ids.length,  "User has not enough balance.");

        SafeERC20Upgradeable.safeTransferFrom(meto, msg.sender, address(this), totalPrice);
    
        for (uint i = 0; i < _ids.length; i++) {
            _safeMint(msg.sender, _ids[i]);
            //insert minted nft to user collection
            collection[msg.sender].push(_ids[i]);
        }

        emit MultipleMint(msg.sender, _ids, totalPrice);
    }

    // mint mint single  nft with USDT asset
    function mintWithUsdt(uint256 _tid)
        public Mintable(_tid)
        returns (uint256)
    {
        require(usdt.balanceOf(msg.sender) > LAND_PRICE_USDT, "User has not enough balance for this nft.");
        //check _tid not belongs to privateSaleLands then first make payment
        if (privateSaleLands[_tid] != msg.sender) {
            SafeERC20Upgradeable.safeTransferFrom(usdt, msg.sender, address(this), LAND_PRICE_USDT);
        }
        _safeMint(msg.sender, _tid);
        //insert minted nft to user collection
        collection[msg.sender].push(_tid);
        emit Mint(msg.sender, _tid, LAND_PRICE_USDT);
        return _tid;
    }

        // mint mint multiple nfts 
    function mintMultipleNftWithUsdt(uint256[] memory _ids) public 
    {
        require(_ids.length > 0, "_ids size can not be zero.");
        uint256 totalPrice = LAND_PRICE_USDT * _ids.length;
        require(usdt.balanceOf(msg.sender) > LAND_PRICE_USDT * _ids.length,  "User has not enough balance.");

        SafeERC20Upgradeable.safeTransferFrom(usdt, msg.sender, address(this), totalPrice);
    
        for (uint i = 0; i < _ids.length; i++) {
            _safeMint(msg.sender, _ids[i]);
            //insert minted nft to user collection
            collection[msg.sender].push(_ids[i]);
        }

        emit MultipleMint(msg.sender, _ids, totalPrice);
    }

    // claim mint single nft without payment and available from launchpad
    function caim(uint256 _id)
        public Claimable
        returns (uint256)
    {
        require(launchpadLands[msg.sender].ClaimedCount <= launchpadLands[msg.sender].ClaimableCount, "reach calimable limit.");
        _safeMint(msg.sender, _id);
        //increase user claimed land count
        launchpadLands[msg.sender].ClaimedCount++;
        //insert minted nft to user collection
        collection[msg.sender].push(_id);
        emit Claim(msg.sender, _id, launchpadLands[msg.sender].ClaimableCount, launchpadLands[msg.sender].ClaimedCount);
        return _id;
    }

    // check given _tid inside disabledLand or not
    function isDisabledLand(uint256 _tid) private view returns(bool)
    {
        for (uint256 i = 0; i < disabledLands.length; i++) {
            if (disabledLands[i] == _tid) {
                return true;
            }
        }

        return false;
    }

    function _isSaleOpened(uint256 _tid) internal view returns(bool)
    {
        if (privateSaleLands[_tid] != address(0) && !privateSaleStatus) {
            return false;
        }
        if (whiteListAddresses[msg.sender] && !whiteListSaleStatus) {
            return false;
        }
        if (!publicSaleStatus) {
            return false;
        }
        return true;
    }
}