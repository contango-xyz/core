//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../libraries/DataTypes.sol";
import "../ContangoPositionNFT.sol";

interface IContangoAdminEvents {
    event ClosingOnlySet(bool closingOnly);
    event ClosingOnlySet(Symbol indexed symbol, bool closingOnly);
    event FeeModelUpdated(Symbol indexed symbol, IFeeModel feeModel);
    event PositionNFTSet(ContangoPositionNFT positionNFT);
    event TokenTrusted(address indexed token, bool trusted);
    event TreasurySet(address treasury);
}

interface IContangoAdmin is IContangoAdminEvents {
    function setClosingOnly(bool closingOnly) external;
    function setClosingOnly(Symbol symbol, bool closingOnly) external;
    function setFeeModel(Symbol symbol, IFeeModel feeModel) external;
    function setTrustedToken(address token, bool trusted) external;
}
