import { Address, Abi } from 'viem'
import DatasetTokenABI from '../abis/DatasetToken.json'
import DatasetBondingCurveABI from '../abis/DatasetBondingCurve.json'
import USDCABI from '../abis/USDC.json'

export const CONTRACTS = {
    DATASET_TOKEN: process.env.NEXT_PUBLIC_DATASET_TOKEN_ADDRESS as Address,
    DATASET_BONDING_CURVE: process.env.NEXT_PUBLIC_BONDING_CURVE_ADDRESS as Address,
    USDC: process.env.NEXT_PUBLIC_USDC_ADDRESS as Address,
}

// Add your contract ABIs here after deployment
export const ABIS = {
    DATASET_TOKEN: DatasetTokenABI as Abi,
    DATASET_BONDING_CURVE: DatasetBondingCurveABI as Abi,
    USDC: USDCABI as Abi,
} 