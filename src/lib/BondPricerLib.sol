// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title BondPricerLib
 * @notice Library providing a function to calculate how many Asset tokens
 *         can be redeemed from a bond amount (denominated in USDC, 6 decimals)
 *         given a Uniswap V3 sqrtPriceX96 for the Asset/USDC pair.
 *
 * @dev
 * - token0 = Asset (assumed 18 decimals)
 * - token1 = USDC  (6 decimals)
 * Thus, the pool's sqrtPriceX96 encodes:
 *
 *        rawRatio = ( (sqrtPriceX96)^2 / 2^192 )
 *                  = (USDC_baseunits / Asset_baseunits).
 *
 * Because Asset has 18 decimals and USDC has 6, there's a 12-decimal difference
 * to reconcile. We multiply the raw ratio by 1e12 to convert “baseunits ratio”
 * into a “human-friendly ratio” of USDC(1e6) per Asset(1e18),
 * and then we keep a final 1e18 scale for typical fixed-point usage.
 */
library BondPricerLib {
    /**
     * @notice Calculates how many Asset tokens the user gets if they redeem
     *         `bondAmountUsdc1e6` worth of bonds into Asset at the given price.
     *
     * @param bondAmountUsdc1e6 The bond amount in USDC with 6 decimals
     *                          (e.g., 1 USDC = 1,000,000).
     * @param strikeSqrtAssetUsdc The sqrtPriceX96 from the Asset/USDC pool,
     *        where token0=Asset(18 dec), token1=USDC(6 dec).
     *        If we square and shift, we get “USDC baseunits per Asset baseunits.”
     *
     * @return assetAmount A raw integer representing the Asset amount in 1e18 scale.
     *         (If your Asset token also uses 18 decimals, this aligns naturally.)
     */
    function getAssetAmountFromBond(uint256 bondAmountUsdc1e6, uint160 strikeSqrtAssetUsdc)
        internal
        pure
        returns (uint256 assetAmount)
    {
        // ------------------------------------------------
        // 1) Convert sqrtPrice into "USDC per Asset"
        //    in 1e18 "fixed-point" form
        // ------------------------------------------------
        // rawRatio = ( (strikeSqrtAssetUsdc^2) >> 192 )
        //         = USDC_baseunits / Asset_baseunits
        //
        // Then multiply by 1e18 for standard fixed-point scaling:
        uint256 strikeUsdcPerAsset_1e18 = (uint256(strikeSqrtAssetUsdc) * uint256(strikeSqrtAssetUsdc) * 1e18) >> 192;

        // Because USDC has 6 decimals vs Asset's 18 decimals,
        // we multiply by an additional 1e12 to align them (18 - 6 = 12).
        strikeUsdcPerAsset_1e18 = strikeUsdcPerAsset_1e18 * 1e12;

        // ------------------------------------------------
        // 2) Convert USDC from 6 decimals to 1e18
        // ------------------------------------------------
        // e.g. 1 USDC = 1,000,000 (bondAmountUsdc1e6),
        // multiplying by 1e12 => 1 USDC => 1e18 in internal math
        uint256 bondAmountUsdc_1e18 = bondAmountUsdc1e6 * 1e12;

        // ------------------------------------------------
        // 3) Final Asset amount in 1e18
        // ------------------------------------------------
        // If strikeUsdcPerAsset_1e18 ~ 3e18 => "1 Asset = 3 USDC"
        // => "1 USDC = ~0.3333 Asset."
        //
        // So assetAmount = (bondInUSDC e18) / (USDC_per_Asset e18).
        // We multiply by 1e18 again to ensure the result is in 1e18 scale
        // if our Asset has 18 decimals.
        assetAmount = (bondAmountUsdc_1e18 * 1e18) / strikeUsdcPerAsset_1e18;
    }
}
