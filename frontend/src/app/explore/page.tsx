'use client';

import { useState, useEffect } from 'react';
import { useReadContract } from 'wagmi';
import { contracts } from '@/contracts/addresses';
import { SolarProjectABI } from '@/contracts/abis/SolarProjectABI';
import { ProjectCard } from '@/components/ProjectCard';
import { MintButton } from '@/components/MintButton';

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
    address: contracts.sepolia.solarProject,
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

  const { data: projectCount, isLoading: countLoading } = useReadContract({
    address: contracts.sepolia.solarProject,
    abi: SolarProjectABI,
    functionName: 'projectCount',
  });

  const count = projectCount ? Number(projectCount) : 0;
  const projectIds = Array.from({ length: count }, (_, i) => BigInt(i + 1));

  const handleLoaded = (id: bigint, data: ProjectData) => {
    setProjects((prev) => new Map(prev).set(id.toString(), data));
  };

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

      {/* Content */}
      {countLoading ? (
        <div className="flex items-center justify-center py-24">
          <div className="text-center">
            <svg
              className="animate-spin h-8 w-8 text-green-500 mx-auto mb-3"
              viewBox="0 0 24 24"
              fill="none"
            >
              <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
              <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
            </svg>
            <p className="text-slate-400">Loading projects...</p>
          </div>
        </div>
      ) : count === 0 ? (
        <div className="text-center py-24">
          <div className="w-16 h-16 bg-slate-800 rounded-2xl flex items-center justify-center mx-auto mb-4">
            <svg className="w-8 h-8 text-slate-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5}
                d="M12 3v1m0 16v1m9-9h-1M4 12H3m15.364 6.364l-.707-.707M6.343 6.343l-.707-.707m12.728 0l-.707.707M6.343 17.657l-.707.707M16 12a4 4 0 11-8 0 4 4 0 018 0z"
              />
            </svg>
          </div>
          <h3 className="text-white font-semibold text-lg mb-2">No Projects Yet</h3>
          <p className="text-slate-400 text-sm mb-6">Be the first to create a solar project.</p>
          <a href="/host" className="bg-green-600 hover:bg-green-500 text-white font-medium py-2.5 px-6 rounded-xl transition-colors">
            Create Project
          </a>
        </div>
      ) : filtered.length === 0 ? (
        <div className="text-center py-16">
          <p className="text-slate-400">No projects match this filter.</p>
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
