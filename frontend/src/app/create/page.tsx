'use client'

import { CreateDatasetForm } from '../../components/CreateDatasetForm'
import { ConnectButton } from '@rainbow-me/rainbowkit'
import Link from 'next/link'

export default function CreateDataset() {
    return (
        <main className="min-h-screen bg-gray-50 py-12">
            <div className="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8">
                <div className="flex justify-between items-center mb-8">
                    <div>
                        <h1 className="text-3xl font-bold text-gray-900">Create New Dataset</h1>
                        <Link
                            href="/"
                            className="text-blue-600 hover:text-blue-800 mt-2 inline-block"
                        >
                            ← Back to Marketplace
                        </Link>
                    </div>
                    <ConnectButton />
                </div>

                <CreateDatasetForm />
            </div>
        </main>
    )
} 