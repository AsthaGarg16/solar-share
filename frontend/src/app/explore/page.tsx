'use client';

import { useState, useEffect, useCallback } from 'react';
import { useReadContract } from 'wagmi';
// Change 'contracts' to 'CONTRACT_ADDRESSES' to match our new file
import { CONTRACT_ADDRESSES } from '@/contracts/addresses'; 
import { SolarProjectABI } from '@/contracts/abis/SolarProjectABI';
import { ProjectCard } from '@/components/ProjectCard';
import { MintButton } from '@/components/MintButton';
import { useProjectCount } from '@/hooks/useContracts';

type ProjectData = {
  projectId: bigint;
  host: `0x${string}`;
  targetAmount: bigint;
  amountRaised: bigint;
  totalShares: bigint;
  sharesSold: bigint;
  pricePerShare: bigint;
  termMonths: bigint;
  startDate: bigint;
  isFunded: boolean;
  isBoughtOut: boolean;
  status: number;
};

function ProjectLoader({
  projectId,
  onLoaded,
}: {
  projectId: bigint;
  onLoaded: (id: bigint, data: ProjectData) => void;
}) {
  const { data } = useReadContract({
    // FIXED: Point to the direct address key
    address: CONTRACT_ADDRESSES.solarProject, 
    abi: SolarProjectABI,
    functionName: 'getProjectDetails',
    args: [projectId],
  });

  useEffect(() => {
    if (data) {
      onLoaded(projectId, data as ProjectData);
    }
  }, [data, projectId, onLoaded]);

  return null;
}

export default function ExplorePage() {
  const [projects, setProjects] = useState<Map<string, ProjectData>>(new Map());
  const [statusFilter, setStatusFilter] = useState<number | null>(null);

  // FIXED: Use the hook we already perfected to avoid path errors
  const { data: projectCount, isLoading: countLoading } = useProjectCount();

  const count = projectCount ? Number(projectCount) : 0;
  const projectIds = Array.from({ length: count }, (_, i) => BigInt(i + 1));

  // Wrapped in useCallback to prevent infinite re-renders
  const handleLoaded = useCallback((id: bigint, data: ProjectData) => {
    setProjects((prev) => {
      const next = new Map(prev);
      next.set(id.toString(), data);
      return next;
    });
  }, []);

  const allProjects = Array.from(projects.values());
  const filtered =
    statusFilter === null
      ? allProjects
      : allProjects.filter((p) => p.status === statusFilter);

  const STATUS_FILTERS = [
    { label: 'All', value: null },
    { label: 'Funding', value: 0 },
    { label: 'Active', value: 1 },
    { label: 'Defaulted', value: 2 },
    { label: 'Bought Out', value: 3 },
  ];

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-10">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-8">
        <div>
          <h1 className="text-3xl font-bold text-white">Solar Projects</h1>
          <p className="text-slate-400 mt-1">
            {count} project{count !== 1 ? 's' : ''} on-chain
          </p>
        </div>
        <MintButton />
      </div>

      {/* Loaders (invisible, just trigger reads) */}
      {projectIds.map((id) => (
        <ProjectLoader key={id.toString()} projectId={id} onLoaded={handleLoaded} />
      ))}

      {/* Filter tabs */}
      <div className="flex gap-2 flex-wrap mb-8">
        {STATUS_FILTERS.map((f) => (
          <button
            key={f.label}
            onClick={() => setStatusFilter(f.value)}
            className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
              statusFilter === f.value
                ? 'bg-green-600 text-white'
                : 'bg-slate-800 text-slate-400 hover:text-white hover:bg-slate-700'
            }`}
          >
            {f.label}
          </button>
        ))}
      </div>

      {/* Content Section */}
      {countLoading ? (
        <div className="flex items-center justify-center py-24">
          <div className="text-center">
             {/* Spinner Logic */}
             <p className="text-slate-400">Syncing with Local Blockchain...</p>
          </div>
        </div>
      ) : count === 0 ? (
        <div className="text-center py-24">
          <h3 className="text-white font-semibold text-lg mb-2">No Projects Yet</h3>
          <p className="text-slate-400 text-sm mb-6">Your Anvil node is fresh. Create your first project to see it here!</p>
          <a href="/host" className="bg-green-600 hover:bg-green-500 text-white font-medium py-2.5 px-6 rounded-xl transition-colors">
            Create Project
          </a>
        </div>
      ) : (
        <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-5">
          {filtered.map((project) => (
            <ProjectCard
              key={project.projectId.toString()}
              projectId={project.projectId}
              host={project.host}
              targetAmount={project.targetAmount}
              amountRaised={project.amountRaised}
              totalShares={project.totalShares}
              sharesSold={project.sharesSold}
              pricePerShare={project.pricePerShare}
              termMonths={project.termMonths}
              isFunded={project.isFunded}
              status={project.status}
            />
          ))}
        </div>
      )}
    </div>
  );
}
