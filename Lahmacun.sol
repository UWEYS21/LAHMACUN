// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
    $LAH - LAHMACUN TOKEN 🌯
    - Max Wallet: 1% (1,000,000,000,000 LAH)
    - Max Transaction: 0.5% (500,000,000,000 LAH)
    - Burn: 1%
    - Tax: 2% Buy / 5% Sell
*/

abstract context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }
}

abstract contract Ownable is context {
    address private _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _transferOwnership(_msgSender());
    }

    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

contract LAHMACUN is context, IERC20, Ownable {
    using SafeMath for uint256;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) private _isExcludedFromFee;

    uint256 private constant _tTotal = 100000000000000 * 10**18; // 100 Trilyon
    uint256 public maxWalletAmount = _tTotal.div(100); // %1 limit
    uint256 public maxTxAmount = _tTotal.div(200);    // %0.5 limit
    
    string private constant _name = "LAHMACUN";
    string private constant _symbol = "LAH";
    uint8 private constant _decimals = 18;

    uint256 public buyTax = 2; 
    uint256 public sellTax = 5;
    uint256 public burnTax = 1;

    constructor() {
        _balances[_msgSender()] = _tTotal;
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;
        emit Transfer(address(0), _msgSender(), _tTotal);
    }

    function name() public pure returns (string memory) { return _name; }
    function symbol() public pure returns (string memory) { return _symbol; }
    function decimals() public pure returns (uint8) { return _decimals; }
    function totalSupply() public view override returns (uint256) { return _tTotal; }
    function balanceOf(address account) public view override returns (uint256) { return _balances[account]; }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount));
        return true;
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(address from, address to, uint256 amount) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");

        if (from != owner() && to != owner()) {
            // Max TX Kontrolü
            require(amount <= maxTxAmount, "Transfer amount exceeds the maxTxAmount.");
            // Max Wallet Kontrolü (Sadece alımlarda)
            if (to != address(0) && to != address(0xdead)) {
                require(balanceOf(to).add(amount) <= maxWalletAmount, "Exceeds maximum wallet token amount.");
            }
        }

        uint256 taxAmount = 0;
        uint256 burnAmount = 0;

        if (!_isExcludedFromFee[from] && !_isExcludedFromFee[to]) {
            // Yakım vergisi her zaman alınır
            burnAmount = amount.mul(burnTax).div(100);
            
            // Alış mı satış mı kontrolü (Basit mantık)
            if (from == owner()) { // Deployment sırasındaki transferler muaf
                taxAmount = 0;
            } else {
                taxAmount = amount.mul(sellTax).div(100); // Varsayılan satış vergisi
            }
        }

        uint256 transferAmount = amount.sub(taxAmount).sub(burnAmount);
        
        _balances[from] = _balances[from].sub(amount);
        _balances[to] = _balances[to].add(transferAmount);
        
        if (burnAmount > 0) {
            _balances[address(0xdead)] = _balances[address(0xdead)].add(burnAmount);
            emit Transfer(from, address(0xdead), burnAmount);
        }

        emit Transfer(from, to, transferAmount);
    }
}
