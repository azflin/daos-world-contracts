import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DaosWorldClaim {
    address public daoToken;
    address public dao;

    event Claimed(address claimer, uint256 amount);

    constructor(address _dao, address _daoToken) {
        dao = _dao;
        daoToken = _daoToken;
    }

    function sendDaoToken(address recipient, uint256 amount) external {
        require(msg.sender == dao);
        // only to handle rounding
        if (ERC20(daoToken).balanceOf(address(this)) < amount) {
            ERC20(daoToken).transfer(recipient, ERC20(daoToken).balanceOf(address(this)));
            emit Claimed(recipient, ERC20(daoToken).balanceOf(address(this)));
        } else {
            ERC20(daoToken).transfer(recipient, amount);
            emit Claimed(recipient, amount);
        }
    }
}
