import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { ABIS, CONTRACTS } from '../config/contracts'
import { parseUnits, createPublicClient, http } from 'viem'
import { sepolia } from 'viem/chains'
import { useEffect } from 'react'

const publicClient = createPublicClient({
    chain: sepolia,
    transport: http()
})

export function useDatasetToken() {
    const { data: allDatasets, isLoading: isLoadingDatasets, refetch: refetchDatasets, error: readError } = useReadContract({
        address: CONTRACTS.DATASET_TOKEN,
        abi: ABIS.DATASET_TOKEN,
        functionName: 'getAllDatasetMetadata',
    })

    // Try reading directly with public client
    const readDirect = async () => {
        try {
            console.log('Checking contract state...')

            // Check if contract is initialized
            const owner = await publicClient.readContract({
                address: CONTRACTS.DATASET_TOKEN,
                abi: ABIS.DATASET_TOKEN,
                functionName: 'owner',
            })
            console.log('Contract owner:', owner)

            // Check USDC address
            const usdc = await publicClient.readContract({
                address: CONTRACTS.DATASET_TOKEN,
                abi: ABIS.DATASET_TOKEN,
                functionName: 'usdc',
            })
            console.log('USDC address:', usdc)

            // Check bonding curve
            const bondingCurve = await publicClient.readContract({
                address: CONTRACTS.DATASET_TOKEN,
                abi: ABIS.DATASET_TOKEN,
                functionName: 'bondingCurve',
            })
            console.log('Bonding curve:', bondingCurve)

            // Try total tokens last
            const totalTokens = await publicClient.readContract({
                address: CONTRACTS.DATASET_TOKEN,
                abi: ABIS.DATASET_TOKEN,
                functionName: 'getTotalTokens',
            })
            console.log('Total tokens:', totalTokens)

        } catch (error) {
            console.error('Direct read error:', error)
        }
    }

    useEffect(() => {
        readDirect()
    }, [])

    console.log('Contract address:', CONTRACTS.DATASET_TOKEN)
    console.log('All datasets:', allDatasets)
    console.log('Loading:', isLoadingDatasets)
    console.log('Read error:', readError)

    const { data: purchasedTokens, isLoading: isLoadingPurchased } = useReadContract({
        address: CONTRACTS.DATASET_TOKEN,
        abi: ABIS.DATASET_TOKEN,
        functionName: 'getPurchasedTokens',
    })

    const { writeContractAsync: purchaseDataset, error: purchaseError } = useWriteContract()
    const { writeContractAsync: mintDatasetToken, error: mintError } = useWriteContract()

    const purchase = async (tokenId: bigint) => {
        try {
            const hash = await purchaseDataset({
                address: CONTRACTS.DATASET_TOKEN,
                abi: ABIS.DATASET_TOKEN,
                functionName: 'purchaseDataset',
                args: [tokenId],
            })

            if (hash) {
                await refetchDatasets()
            }
        } catch (error) {
            console.error('Error purchasing dataset:', error)
            throw error
        }
    }

    const mint = async (params: any) => {
        try {
            console.log('Minting dataset with params:', params)

            const hash = await mintDatasetToken({
                address: CONTRACTS.DATASET_TOKEN,
                abi: ABIS.DATASET_TOKEN,
                functionName: 'mintDatasetToken',
                args: [
                    params.owners,
                    params.name,
                    params.description,
                    params.contentHash,
                    params.ipfsHash,
                    params.initialPrice,
                    params.tags,
                ],
            })

            if (hash) {
                console.log('Transaction hash:', hash)
                console.log('Refreshing datasets...')
                const result = await refetchDatasets()
                console.log('Refetch result:', result)
            }
        } catch (error) {
            console.error('Error minting dataset:', error)
            throw error
        }
    }

    return {
        allDatasets,
        isLoadingDatasets,
        purchasedTokens,
        isLoadingPurchased,
        purchaseDataset: purchase,
        mintDatasetToken: mint,
        purchaseError,
        mintError,
        refetchDatasets,
        readError,
    }
} 