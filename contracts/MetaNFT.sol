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
    IERC20Upgradeable busd;

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    enum ASSET {METO, BUSD}

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
    //block transaction or  set new land price if argument = ID_SKIP_PRICE_VALUE
    uint256 private ID_SKIP_PRICE_VALUE = 9999999999999999;

    uint256 public LAND_PRICE_METO = 1000000000000000;
    uint256 public LAND_PRICE_BUSD = 100;
    uint256 public WHITELIST_PRICE_METO = 1000000000000000;
    uint256 public WHITELIST_PRICE_BUSD = 50;

    uint256 MAX_TID = 24000;
    uint256 MIN_TID = 1;
         
    string public baseTokenURI;
    bool private launchpadSaleStatus;
    bool private whiteListSaleStatus;
    bool private privateSaleStatus;
    bool private publicSaleStatus;

    event MultipleMint(address indexed _from, uint256[] tokenIds, uint256 _price);
    event Claim(address indexed _from, uint256 _tid, uint256 claimableCount, uint256 claimedCount);

    modifier Mintable(uint256 _tid) {
        require(_tid <= MAX_TID && _tid >= MIN_TID, "Invalid tid.");
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
        busd = IERC20Upgradeable(0xeD24FC36d5Ee211Ea25A80239Fb8C4Cfd80f12Ee);
        setBaseURI("ipfs://QmeYyiEmYhGmEuMU8q9uMs7Uprs7KGdEiKBwRpSsoapn2K/");
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

    /* Start of Administrative Functions */
    function setLandPriceWithMeto(uint256 _price, uint256 _whiteListPrice) public onlyOwner 
    {   
        if (_price != ID_SKIP_PRICE_VALUE || _price == LAND_PRICE_METO) {
            LAND_PRICE_METO = _price;
        }
        if ( _whiteListPrice != ID_SKIP_PRICE_VALUE || _whiteListPrice == WHITELIST_PRICE_METO) {
            WHITELIST_PRICE_METO = _whiteListPrice;
        }
    }

    function setMaxAndMinTID(uint256 _min, uint256 _max) public onlyOwner
    {
        require(_min > 0 && _max > 0 && _max > _min, "invalid _max or _min value");
        MIN_TID = _min;
        MAX_TID = _max;
    }

    function withdrawMeto(address payable addr, uint256 _amount) external onlyOwner {
        SafeERC20Upgradeable.safeTransfer(meto, addr, _amount);
    }

    function withdrawBusd(address payable addr, uint256 _amount) external onlyOwner {
        SafeERC20Upgradeable.safeTransfer(busd, addr, _amount);
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

    function mintWithMeto(uint256[] memory _tids) public 
    {
        uint256[] memory filteredLands = filterAvailableLands(_tids);
        uint256 totalPrice = calculateTotalPrice(filteredLands, ASSET.METO);
        require(meto.balanceOf(msg.sender) > totalPrice,  "User has not enough balance.");

        SafeERC20Upgradeable.safeTransferFrom(meto, msg.sender, address(this), totalPrice);
    
        for (uint i = 0; i < filteredLands.length; i++) {
            _safeMint(msg.sender, filteredLands[i]);
            //insert minted nft to user collection
            collection[msg.sender].push(filteredLands[i]);
        }

        emit MultipleMint(msg.sender, filteredLands, totalPrice);
    }

    function mintWithBusd(uint256[] memory _tids) public 
    {
        uint256[] memory filteredLands = filterAvailableLands(_tids);
        uint256 totalPrice = calculateTotalPrice(filteredLands, ASSET.BUSD);
        require(busd.balanceOf(msg.sender) > totalPrice,  "User has not enough balance.");

        SafeERC20Upgradeable.safeTransferFrom(busd, msg.sender, address(this), totalPrice);
    
        for (uint i = 0; i < filteredLands.length; i++) {
            _safeMint(msg.sender, filteredLands[i]);
            //insert minted nft to user collection
            collection[msg.sender].push(filteredLands[i]);
        }

        emit MultipleMint(msg.sender, filteredLands, totalPrice);
    }

    // claim mint single nft without payment and available from launchpad
    function claim(uint256 _id)
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
    
    function filterAvailableLands(uint256[] memory _tids) internal view returns(uint256[] memory filteredLands)
    {
        uint j = 0;
        for (uint256 i = 0; i < _tids.length; i++) {
            uint256 _tid = _tids[i];
            //filter disable, not available for sale
            if (isDisabledLand(_tid) || !_isSaleOpened(_tid)) {
                continue;
            }
            //check if privateSaleLand then user has given access or not
            if (privateSaleLands[_tid] != address(0) && privateSaleLands[_tid] != msg.sender) {
                continue;
            }

            j++;
            filteredLands[j] = _tid;
        }

        return filteredLands;
    }

    function calculateTotalPrice(uint256[] memory _tids, ASSET _asset) public view returns(uint256)
    {
        uint256 _price = 0;

        if (whiteListSaleStatus && whiteListAddresses[msg.sender]) {
            if (_asset == ASSET.METO) {
                _price = WHITELIST_PRICE_METO;
            } else if (_asset == ASSET.BUSD) {
                _price = WHITELIST_PRICE_BUSD;
            }
        } else {
            if (_asset == ASSET.METO) {
                _price = LAND_PRICE_METO;
            } else if (_asset == ASSET.BUSD) {
                _price = LAND_PRICE_BUSD;
            }
        }

        uint256 total = _price * _tids.length;

        for(uint256 i = 0; i<_tids.length; i++) {   
            if (privateSaleLands[_tids[i]] == msg.sender) {
                total -= _price;
            }
        }

        return total;
    }
}