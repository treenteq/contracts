import { useReadContract } from 'wagmi'
import { ABIS, CONTRACTS } from '../config/contracts'

export function useBondingCurve(tokenId: bigint) {
  const { data: currentPrice, isLoading: isLoadingPrice } = useReadContract({
    address: CONTRACTS.DATASET_BONDING_CURVE,
    abi: ABIS.DATASET_BONDING_CURVE,
    functionName: 'getCurrentPrice',
    args: [tokenId],
  })

  const { data: purchaseCount } = useReadContract({
    address: CONTRACTS.DATASET_BONDING_CURVE,
    abi: ABIS.DATASET_BONDING_CURVE,
    functionName: 'tokenPurchaseCount',
    args: [tokenId],
  })

  const { data: lastPurchaseTime } = useReadContract({
    address: CONTRACTS.DATASET_BONDING_CURVE,
    abi: ABIS.DATASET_BONDING_CURVE,
    functionName: 'lastPurchaseTimestamp',
    args: [tokenId],
  })

  return {
    currentPrice,
    isLoadingPrice,
    purchaseCount,
    lastPurchaseTime,
  }
} 