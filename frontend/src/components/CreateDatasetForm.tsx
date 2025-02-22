import { useState } from 'react'
import { useDatasetToken } from '../hooks/useDatasetToken'
import { parseUnits } from 'viem'
import { useAccount } from 'wagmi'

interface Owner {
    address: string
    percentage: number
}

export function CreateDatasetForm() {
    const { mintDatasetToken, mintError } = useDatasetToken()
    const { address } = useAccount()
    const [isSubmitting, setIsSubmitting] = useState(false)
    const [error, setError] = useState<string | null>(null)
    const [success, setSuccess] = useState(false)
    const [name, setName] = useState('')
    const [description, setDescription] = useState('')
    const [contentHash, setContentHash] = useState('')
    const [ipfsHash, setIpfsHash] = useState('')
    const [initialPrice, setInitialPrice] = useState('')
    const [tags, setTags] = useState<string[]>([])
    const [tagInput, setTagInput] = useState('')
    const [owners, setOwners] = useState<Owner[]>([{ address: '', percentage: 0 }])

    const handleAddTag = () => {
        if (tagInput && !tags.includes(tagInput)) {
            setTags([...tags, tagInput])
            setTagInput('')
        }
    }

    const handleRemoveTag = (tagToRemove: string) => {
        setTags(tags.filter(tag => tag !== tagToRemove))
    }

    const handleAddOwner = () => {
        setOwners([...owners, { address: '', percentage: 0 }])
    }

    const handleRemoveOwner = (index: number) => {
        setOwners(owners.filter((_, i) => i !== index))
    }

    const handleOwnerChange = (index: number, field: keyof Owner, value: string) => {
        const newOwners = [...owners]
        if (field === 'percentage') {
            newOwners[index][field] = parseInt(value) || 0
        } else {
            newOwners[index][field] = value as string
        }
        setOwners(newOwners)
    }

    const resetForm = () => {
        setName('')
        setDescription('')
        setContentHash('')
        setIpfsHash('')
        setInitialPrice('')
        setTags([])
        setOwners([{ address: '', percentage: 0 }])
    }

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault()
        setIsSubmitting(true)
        setError(null)
        setSuccess(false)

        try {
            if (!address) {
                throw new Error('Please connect your wallet first')
            }

            const totalPercentage = owners.reduce((sum, owner) => sum + owner.percentage, 0)
            if (totalPercentage !== 100) {
                throw new Error('Total ownership percentage must equal 100%')
            }

            // Convert percentage to basis points (100% = 10000)
            const ownersForContract = owners.map(owner => ({
                owner: owner.address,
                percentage: owner.percentage * 100
            }))

            console.log('Submitting dataset with params:', {
                owners: ownersForContract,
                name,
                description,
                contentHash,
                ipfsHash,
                initialPrice: parseUnits(initialPrice, 6),
                tags
            })

            const tx = await mintDatasetToken({
                owners: ownersForContract,
                name,
                description,
                contentHash,
                ipfsHash,
                initialPrice: parseUnits(initialPrice, 6),
                tags
            })

            console.log('Transaction submitted:', tx)
            setSuccess(true)
            resetForm()
        } catch (err: any) {
            console.error('Error creating dataset:', err)
            setError(err.message || 'Failed to create dataset')
        } finally {
            setIsSubmitting(false)
        }
    }

    return (
        <form onSubmit={handleSubmit} className="space-y-6 bg-white p-6 rounded-lg shadow">
            {error && (
                <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded">
                    {error}
                </div>
            )}
            {success && (
                <div className="bg-green-50 border border-green-200 text-green-700 px-4 py-3 rounded">
                    Dataset created successfully!
                </div>
            )}
            {mintError && (
                <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded">
                    {mintError.message}
                </div>
            )}

            <div>
                <label className="block text-sm font-medium text-gray-700">Name</label>
                <input
                    type="text"
                    value={name}
                    onChange={(e) => setName(e.target.value)}
                    className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                    required
                />
            </div>

            <div>
                <label className="block text-sm font-medium text-gray-700">Description</label>
                <textarea
                    value={description}
                    onChange={(e) => setDescription(e.target.value)}
                    className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                    rows={3}
                    required
                />
            </div>

            <div>
                <label className="block text-sm font-medium text-gray-700">Content Hash</label>
                <input
                    type="text"
                    value={contentHash}
                    onChange={(e) => setContentHash(e.target.value)}
                    className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                    required
                />
            </div>

            <div>
                <label className="block text-sm font-medium text-gray-700">IPFS Hash</label>
                <input
                    type="text"
                    value={ipfsHash}
                    onChange={(e) => setIpfsHash(e.target.value)}
                    className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                    required
                />
            </div>

            <div>
                <label className="block text-sm font-medium text-gray-700">Initial Price (USDC)</label>
                <input
                    type="number"
                    value={initialPrice}
                    onChange={(e) => setInitialPrice(e.target.value)}
                    className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                    min="0"
                    step="0.000001"
                    required
                />
            </div>

            <div>
                <label className="block text-sm font-medium text-gray-700">Tags</label>
                <div className="flex gap-2 mt-1">
                    <input
                        type="text"
                        value={tagInput}
                        onChange={(e) => setTagInput(e.target.value)}
                        className="block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                    />
                    <button
                        type="button"
                        onClick={handleAddTag}
                        className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700"
                    >
                        Add Tag
                    </button>
                </div>
                <div className="flex flex-wrap gap-2 mt-2">
                    {tags.map((tag) => (
                        <span
                            key={tag}
                            className="px-2 py-1 bg-blue-100 text-blue-800 rounded-full text-sm flex items-center gap-2"
                        >
                            {tag}
                            <button
                                type="button"
                                onClick={() => handleRemoveTag(tag)}
                                className="text-blue-600 hover:text-blue-800"
                            >
                                ×
                            </button>
                        </span>
                    ))}
                </div>
            </div>

            <div>
                <label className="block text-sm font-medium text-gray-700">Owners</label>
                <div className="space-y-4">
                    {owners.map((owner, index) => (
                        <div key={index} className="flex gap-4 items-start">
                            <div className="flex-grow">
                                <input
                                    type="text"
                                    value={owner.address}
                                    onChange={(e) => handleOwnerChange(index, 'address', e.target.value)}
                                    placeholder="Owner address"
                                    className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                                    required
                                />
                            </div>
                            <div className="w-32">
                                <input
                                    type="number"
                                    value={owner.percentage}
                                    onChange={(e) => handleOwnerChange(index, 'percentage', e.target.value)}
                                    placeholder="Percentage"
                                    className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                                    min="0"
                                    max="100"
                                    required
                                />
                            </div>
                            {owners.length > 1 && (
                                <button
                                    type="button"
                                    onClick={() => handleRemoveOwner(index)}
                                    className="mt-1 text-red-600 hover:text-red-800"
                                >
                                    Remove
                                </button>
                            )}
                        </div>
                    ))}
                    <button
                        type="button"
                        onClick={handleAddOwner}
                        className="mt-2 text-blue-600 hover:text-blue-800"
                    >
                        + Add Owner
                    </button>
                </div>
            </div>

            <button
                type="submit"
                disabled={isSubmitting || !address}
                className={`w-full py-2 px-4 rounded-lg transition-colors ${isSubmitting || !address
                        ? 'bg-gray-400 cursor-not-allowed'
                        : 'bg-blue-600 hover:bg-blue-700 text-white'
                    }`}
            >
                {isSubmitting ? 'Creating Dataset...' : 'Create Dataset'}
            </button>

            {!address && (
                <p className="text-sm text-red-600 text-center">
                    Please connect your wallet to create a dataset
                </p>
            )}
        </form>
    )
} 