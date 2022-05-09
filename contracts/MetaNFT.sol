//Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";


contract MetaNFT is ERC721Enumerable, Ownable  {

    IERC20Upgradeable meto;
    IERC20 usdt;

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
    //calimablelar hansiki mintde pul vermirler istenilen bosh yeri sece bilerler. address => ala_bileceyi_nft_sayi_model
    //claimable_count, claimed_count saylari, pulsuz claim eledikce claimed_count say artir claimable_counta-qeder
    mapping(address => OptionLaunchpadLand) public launchpadLands;

    uint256 LAND_PRICE_METO = 1000000000000000;
    uint256 LAND_PRICE_USDT = 100;

    //keep land max tid (technical id)
    uint256 TID_MAX_INTERVAL = 24000;

    //kep plot min tid (technical_id)
    uint256 TID_MIN_INTERVAL = 1;
 
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
        
    string public baseTokenURI;

    uint256 private ID_NOT_FOUND = 9999999999999999;

    bool private launchpadSaleStatus;
    bool private whiteListSaleStatus;
    bool private privateSaleStatus;
    bool private publicSaleStatus;

    //event Mint fire after mint()
    event Mint(address indexed _from, uint256 tokenId, uint256 _price);

    //event Mint fire after mintNfts()
    event MultipleMint(address indexed _from, uint256[] tokenIds, uint256 _price);
    
    //event Claim fire after claim()
    event Claim(address indexed _from, uint256 _tid, uint256 claimableCount, uint256 claimedCount);

    //check given _tid can mint or not
    modifier Mintable(uint256 _tid) {
        require(_tid <= TID_MAX_INTERVAL && _tid >= TID_MIN_INTERVAL, "Invalid tid.");
        require(!isDisabledLand(_tid), "The given tid is inside disabledLands.");
        //check land sale status is opened(true)
        require(_isSaleOpened(_tid), "The sale not opened yet.");
        _;
    }
    
    //check claim is available or not
    modifier Claimable () {
        require(launchpadSaleStatus, "Launchad sale not opened yet.");
        _;
    }

    constructor() ERC721("MyNFT", "NFT") {
        meto = IERC20Upgradeable(0xc39A5f634CC86a84147f29a68253FE3a34CDEc57);
        usdt = IERC20(0x337610d27c682E347C9cD60BD4b3b107C9d34dDd);
        setBaseURI("ipfs://QmeYyiEmYhGmEuMU8q9uMs7Uprs7KGdEiKBwRpSsoapn2K/");
    }

    /* Start of Administrative Functions */

    function setLandPriceWithMeto(uint256 v) public onlyOwner 
    {
        LAND_PRICE_METO = v;
    }

    function setLandPriceWithUSDT(uint256 v) public onlyOwner 
    {
        LAND_PRICE_USDT = v;
    }

    //set TID_MAX_INTERVAL value by owner
    function setTIDMaxInterval(uint256 v) public onlyOwner
    {
        TID_MAX_INTERVAL = v;
    }

    //set TID_MIN_INTERVAL value by owner
    function setTIDMinInterval(uint256 v) public onlyOwner
    {
        TID_MIN_INTERVAL = v;
    }

    // withdraw contract balance to owner wallet
    function withdraw(address payable addr, uint amount) external onlyOwner {
        SafeERC20Upgradeable.safeTransfer(meto, addr, amount);
    }


    // set lands as disabled
    function setLandAsDisabled(uint256[] memory _tids) public onlyOwner 
    {
        for (uint i = 0; i < _tids.length; i++) {
            disabledLands.push(_tids[i]);
        }
    }

    //remove given tid form disabledLands
    function removeDisableLand(uint256 _tid) public onlyOwner 
    {
        uint256 _index = getDisabledLandIndex(_tid);
        require(_index != ID_NOT_FOUND, "index out of bound.");

        for (uint i = _index; i < disabledLands.length - 1; i++) {
            disabledLands[i] = disabledLands[i + 1];
        }

        disabledLands.pop();
    }

    //find index by given _tid
    function getDisabledLandIndex(uint256 _tid) private view returns(uint256)
    {
        for (uint256 i = 0; i < disabledLands.length; i++) {
            if (disabledLands[i] == _tid) {
                return i;
            }
        }

        return ID_NOT_FOUND;
    }

    //set pirvate land
    function setPrivateSaleLand(uint256 _tid, address _owner) public onlyOwner Mintable(_tid)
    {
        privateSaleLands[_tid] = _owner;
    }

    //set launchpad land
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

        //set launchpad sale open/close
    function setLaunchpadSaleStatus(bool _status) public onlyOwner
    {
        launchpadSaleStatus = _status;
    }

    //set whitelist sale open/close
    function setWhitelistSaleStatus(bool _status) public onlyOwner
    {
        whitelistSaleStatus = _status;
    }

    //set private sale open/close
    function setPrivateSaleStatus(bool _status) public onlyOwner
    {
        privateSaleStatus = _status;
    }

    //set public sale open/close
    function setPublicSaleStatus(bool _status) public onlyOwner
    {
        publicSaleStatus = _status;
    }

    /* End of Administrative Functions */

    // return user nft collection 
    function myCollection() public view returns(uint256[] memory)
    {
        return collection[msg.sender];
    }

    /*
     * mint mint single or multiple nft
     * @param address recipient
     * @param string[] memory tokenUris
     * @returns uint256[] memory
    */
    function mint(uint256 _tid)
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

    /*
     * mint mint multiple nfts 
     * @param address recipient
     * @param string[] memory tokenUris
     * @returns uint256[] memory
    */
    function mintNfts(uint256[] memory _ids) public 
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

    /*
     * mint mint single  nft with USDT asset
     * @param address recipient
     * @param string[] memory tokenUris
     * @returns uint256[] memory
    */
    function mintWithUsdt(uint256 _tid)
        public Mintable(_tid)
        returns (uint256)
    {

        require(usdt.balanceOf(msg.sender) > LAND_PRICE_USDT, "User has not enough balance for this nft.");

        //check _tid not belongs to privateSaleLands then first make payment
        if (privateSaleLands[_tid] != msg.sender) {
            SafeERC20.safeTransferFrom(usdt, msg.sender, address(this), LAND_PRICE_USDT);
        }

        _safeMint(msg.sender, _tid);

        //insert minted nft to user collection
        collection[msg.sender].push(_tid);

        emit Mint(msg.sender, _tid, LAND_PRICE_USDT);
        return _tid;
    }

    /*
     * claim mint single nft without payment and available from launchpad
     * @param address recipient
     * @param string[] memory tokenUris
     * @returns uint256[] memory
    */
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
        
        //check private sale status
        if (privateSaleLands[_tid] != address(0) && !privateSaleStatus) {
            return false;
        }

        //check whitelist sale status
        if (whiteListAddresses[msg.sender] && !whiteListSaleStatus) {
            return false;
        }

        //check public sale status
        if (!publicSaleStatus) {
            return false;
        }

        return true;
    }
}