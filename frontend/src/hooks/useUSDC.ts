import { createPublicClient, http } from 'viem'
import { ABIS, CONTRACTS } from '../config/contracts'
import { useAccount, useWriteContract } from 'wagmi'
import { sepolia } from 'viem/chains'

const publicClient = createPublicClient({
    chain: sepolia,
    transport: http()
})

export function useUSDC() {
    const { address } = useAccount()
    const { writeContractAsync: approveUSDC } = useWriteContract()

    const getAllowance = async () => {
        if (!address) return BigInt(0)
        return publicClient.readContract({
            address: CONTRACTS.USDC,
            abi: ABIS.USDC,
            functionName: 'allowance',
            args: [address, CONTRACTS.DATASET_TOKEN],
        })
    }

    const getBalance = async () => {
        if (!address) return BigInt(0)
        return publicClient.readContract({
            address: CONTRACTS.USDC,
            abi: ABIS.USDC,
            functionName: 'balanceOf',
            args: [address],
        })
    }

    const approve = async (amount: bigint) => {
        if (!address) throw new Error('No wallet connected')

        try {
            const hash = await approveUSDC({
                address: CONTRACTS.USDC,
                abi: ABIS.USDC,
                functionName: 'approve',
                args: [CONTRACTS.DATASET_TOKEN, amount],
            })

            return hash
        } catch (error) {
            console.error('Error approving USDC:', error)
            throw error
        }
    }

    return {
        getAllowance,
        getBalance,
        approve,
    }
} 