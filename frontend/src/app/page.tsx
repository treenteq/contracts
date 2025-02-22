'use client'

import { useDatasetToken } from '../hooks/useDatasetToken'
import { DatasetCard } from '../components/DatasetCard'
import { ConnectButton } from '@rainbow-me/rainbowkit'
import Link from 'next/link'
import { useEffect } from 'react'

interface DatasetMetadata {
  name: string
  description: string
  contentHash: string
  ipfsHash: string
  tags: string[]
  owners: Array<{ owner: string; percentage: number }>
  price: bigint
}

export default function Home() {
  const { allDatasets, isLoadingDatasets, refetchDatasets, readError } = useDatasetToken()

  useEffect(() => {
    console.log('Component mounted, fetching datasets...')
    refetchDatasets()
  }, [refetchDatasets])

  return (
    <main className="min-h-screen bg-gray-50 py-12">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex justify-between items-center mb-8">
          <h1 className="text-3xl font-bold text-gray-900">Dataset Marketplace</h1>
          <div className="flex items-center gap-4">
            <Link
              href="/create"
              className="bg-blue-600 text-white py-2 px-4 rounded-lg hover:bg-blue-700 transition-colors"
            >
              Create Dataset
            </Link>
            <ConnectButton />
          </div>
        </div>

        {readError ? (
          <div className="text-center py-12">
            <p className="text-lg text-red-600">Error loading datasets: {readError.message}</p>
            <button
              onClick={() => refetchDatasets()}
              className="mt-4 text-blue-600 hover:text-blue-800"
            >
              Try Again
            </button>
          </div>
        ) : isLoadingDatasets ? (
          <div className="text-center py-12">
            <p className="text-lg text-gray-600">Loading datasets...</p>
          </div>
        ) : allDatasets && Array.isArray(allDatasets) && allDatasets.length > 0 ? (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {allDatasets.map((dataset, index) => (
              <DatasetCard
                key={index}
                tokenId={BigInt(index)}
                name={dataset.name}
                description={dataset.description}
                ipfsHash={dataset.ipfsHash}
                tags={dataset.tags}
                owners={dataset.owners}
              />
            ))}
          </div>
        ) : (
          <div className="text-center py-12">
            <p className="text-lg text-gray-600">No datasets available</p>
            <p className="text-sm text-gray-500 mt-2">Data: {JSON.stringify(allDatasets)}</p>
            <button
              onClick={() => refetchDatasets()}
              className="mt-4 text-blue-600 hover:text-blue-800"
            >
              Refresh Datasets
            </button>
          </div>
        )}
      </div>
    </main>
  )
}
