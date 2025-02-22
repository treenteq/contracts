import { useBondingCurve } from '../hooks/useBondingCurve'
import { formatUnits } from 'viem'
import { useDatasetToken } from '../hooks/useDatasetToken'
import { useUSDC } from '../hooks/useUSDC'
import { useState, useEffect } from 'react'
import { CONTRACTS } from '../config/contracts'

interface DatasetCardProps {
    tokenId: bigint
    name: string
    description: string
    ipfsHash: string
    tags: string[]
    owners: Array<{ owner: string; percentage: number }>
}

export function DatasetCard({
    tokenId,
    name,
    description,
    ipfsHash,
    tags,
    owners,
}: DatasetCardProps) {
    const { currentPrice, isLoadingPrice } = useBondingCurve(tokenId)
    const { purchaseDataset } = useDatasetToken()
    const { getAllowance, getBalance, approve } = useUSDC()
    const [isApproving, setIsApproving] = useState(false)
    const [isPurchasing, setIsPurchasing] = useState(false)
    const [allowance, setAllowance] = useState<bigint>(BigInt(0))
    const [balance, setBalance] = useState<bigint>(BigInt(0))

    const price = currentPrice ? (currentPrice as bigint) : BigInt(0)

    useEffect(() => {
        const updateBalances = async () => {
            const [newAllowance, newBalance] = await Promise.all([
                getAllowance(),
                getBalance()
            ])
            setAllowance(newAllowance as bigint)
            setBalance(newBalance as bigint)
        }
        updateBalances()
    }, [getAllowance, getBalance])

    const handleApprove = async () => {
        if (!price) return
        setIsApproving(true)
        try {
            const hash = await approve(price)
            console.log('Approval transaction submitted:', hash)

            // Wait a bit and check the new allowance
            await new Promise(resolve => setTimeout(resolve, 2000))
            const newAllowance = await getAllowance()
            setAllowance(newAllowance as bigint)

            console.log('New allowance:', newAllowance)
        } catch (error) {
            console.error('Error approving USDC:', error)
            alert('Error approving USDC. Check console for details.')
        } finally {
            setIsApproving(false)
        }
    }

    const handlePurchase = async () => {
        if (!price) return
        setIsPurchasing(true)
        try {
            await purchaseDataset(tokenId)
            const [newAllowance, newBalance] = await Promise.all([
                getAllowance(),
                getBalance()
            ])
            setAllowance(newAllowance as bigint)
            setBalance(newBalance as bigint)
        } catch (error) {
            console.error('Error purchasing dataset:', error)
            alert('Error purchasing dataset. Check console for details.')
        } finally {
            setIsPurchasing(false)
        }
    }

    const needsApproval = allowance < price
    const insufficientBalance = balance < price

    return (
        <div className="bg-white rounded-lg shadow-md p-6 space-y-4">
            <div className="flex justify-between items-start">
                <div>
                    <h3 className="text-xl font-semibold">{name}</h3>
                    <p className="text-gray-600 mt-2">{description}</p>
                </div>
                <div className="text-right">
                    <p className="text-sm text-gray-500">Current Price</p>
                    <p className="text-lg font-bold">
                        {isLoadingPrice
                            ? 'Loading...'
                            : `${formatUnits(price, 6)} USDC`}
                    </p>
                </div>
            </div>

            <div className="flex flex-wrap gap-2">
                {tags.map((tag) => (
                    <span
                        key={tag}
                        className="px-2 py-1 bg-blue-100 text-blue-800 rounded-full text-sm"
                    >
                        {tag}
                    </span>
                ))}
            </div>

            <div className="space-y-2">
                <p className="text-sm text-gray-500">Owners:</p>
                {owners.map((owner) => (
                    <div key={owner.owner} className="flex justify-between text-sm">
                        <span className="text-gray-600">{owner.owner}</span>
                        <span className="font-medium">{Number(owner.percentage) / 100}%</span>
                    </div>
                ))}
            </div>

            {insufficientBalance ? (
                <button
                    disabled
                    className="w-full mt-4 bg-gray-400 text-white py-2 px-4 rounded-lg cursor-not-allowed"
                >
                    Insufficient USDC Balance
                </button>
            ) : needsApproval ? (
                <button
                    onClick={handleApprove}
                    disabled={isApproving}
                    className="w-full mt-4 bg-blue-600 text-white py-2 px-4 rounded-lg hover:bg-blue-700 transition-colors disabled:bg-blue-400"
                >
                    {isApproving ? 'Approving...' : 'Approve USDC'}
                </button>
            ) : (
                <button
                    onClick={handlePurchase}
                    disabled={isPurchasing}
                    className="w-full mt-4 bg-blue-600 text-white py-2 px-4 rounded-lg hover:bg-blue-700 transition-colors disabled:bg-blue-400"
                >
                    {isPurchasing ? 'Purchasing...' : 'Purchase Dataset'}
                </button>
            )}
        </div>
    )
} 