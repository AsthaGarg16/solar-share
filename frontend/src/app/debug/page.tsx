'use client';

import { useState } from 'react';
import { useAccount, useReadContract } from 'wagmi';

const LoanManagerABI = [
  {
    type: 'function',
    name: 'checkDefaultStatus',
    inputs: [{ name: 'projectId', type: 'uint256' }],
    outputs: [{ name: 'isDefault', type: 'bool' }],
    stateMutability: 'view',
  },
];

const WeatherOracleABI = [
  {
    type: 'function',
    name: 'getRainyDays',
    inputs: [{ name: 'projectId', type: 'uint256' }],
    outputs: [{ name: '', type: 'uint256' }],
    stateMutability: 'view',
  },
];

const contractAddresses = {
  loanManager: '0x50EEf481cae4250d252Ae577A09bF514f224C6C4',
  weatherOracle: '0xA8452Ec99ce0C64f20701dB7dD3abDb607c00496',
};

export default function DebugPage() {
  const { address } = useAccount();
  const [projectId, setProjectId] = useState('1');
  const [daysToSkip, setDaysToSkip] = useState('15');
  const [loading, setLoading] = useState(false);
  const [lastWeatherCheck, setLastWeatherCheck] = useState<any>(null);
  const [defaultCheckResult, setDefaultCheckResult] = useState<any>(null);

  // Read default status
  const { data: isDefault, refetch: refetchDefault } = useReadContract({
    address: contractAddresses.loanManager as `0x${string}`,
    abi: LoanManagerABI as any,
    functionName: 'checkDefaultStatus',
    args: [BigInt(projectId || '1')],
  });

  // Handle time skip
  const handleSkipTime = async () => {
    const seconds = parseInt(daysToSkip) * 86400;
    setLoading(true);

    try {
      const response = await fetch('/api/debug/skip-time', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ seconds }),
      });

      const data = await response.json();
      if (data.success) {
        alert(`✅ Skipped ${daysToSkip} days successfully!`);
        setTimeout(() => refetchDefault(), 1000);
      } else {
        alert(`❌ Error: ${data.error}`);
      }
    } catch (error) {
      alert(`❌ Error: ${error}`);
    } finally {
      setLoading(false);
    }
  };

  // Check default status
  const handleCheckDefault = async () => {
    await refetchDefault();
    setDefaultCheckResult({
      projectId,
      isDefault,
      timestamp: new Date().toLocaleString(),
    });
  };

  // Check weather (mock)
  const handleCheckWeather = () => {
    const isRaining = Math.random() > 0.5;
    setLastWeatherCheck({
      projectId,
      isRaining,
      timestamp: new Date().toLocaleString(),
    });
  };

  const getStatus = () => {
    if (lastWeatherCheck?.isRaining) {
      return '🌧️ It\'s raining';
    }
    if (isDefault === true) {
      return '🔴 DEFAULT - No rain!';
    }
    return '✅ Normal';
  };

  return (
    <div style={{ padding: '2rem', background: '#0a0a0a', minHeight: '100vh', color: '#fff' }}>
      <h1 style={{ fontSize: '2rem', marginBottom: '2rem' }}>🔧 Debug Panel</h1>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: '1.5rem', marginBottom: '2rem' }}>
        {/* Time Skip */}
        <div style={{ background: '#1a1a1a', border: '1px solid #333', borderRadius: '8px', padding: '1.5rem' }}>
          <h2 style={{ fontSize: '1.25rem', marginBottom: '1rem' }}>⏭️ Skip Time</h2>
          
          <div style={{ marginBottom: '1rem' }}>
            <label style={{ fontSize: '0.875rem', marginBottom: '0.5rem', display: 'block' }}>Project ID</label>
            <input
              type="number"
              value={projectId}
              onChange={(e) => setProjectId(e.target.value)}
              placeholder="1"
              style={{
                width: '100%',
                padding: '0.5rem',
                background: '#2a2a2a',
                color: '#fff',
                border: '1px solid #444',
                borderRadius: '4px',
                fontSize: '1rem',
              }}
            />
          </div>

          <div style={{ marginBottom: '1rem' }}>
            <label style={{ fontSize: '0.875rem', marginBottom: '0.5rem', display: 'block' }}>Days to Skip</label>
            <input
              type="number"
              value={daysToSkip}
              onChange={(e) => setDaysToSkip(e.target.value)}
              placeholder="15"
              style={{
                width: '100%',
                padding: '0.5rem',
                background: '#2a2a2a',
                color: '#fff',
                border: '1px solid #444',
                borderRadius: '4px',
                fontSize: '1rem',
              }}
            />
          </div>

          <button
            onClick={handleSkipTime}
            disabled={loading}
            style={{
              width: '100%',
              padding: '0.75rem',
              background: loading ? '#666' : '#2563eb',
              color: '#fff',
              border: 'none',
              borderRadius: '4px',
              cursor: loading ? 'not-allowed' : 'pointer',
              fontSize: '1rem',
              fontWeight: 'bold',
            }}
          >
            {loading ? '⏳ Processing...' : `⏭️ Skip ${daysToSkip} Days`}
          </button>
        </div>

        {/* Weather Check */}
        <div style={{ background: '#1a1a1a', border: '1px solid #333', borderRadius: '8px', padding: '1.5rem' }}>
          <h2 style={{ fontSize: '1.25rem', marginBottom: '1rem' }}>🌦️ Weather Check</h2>

          {lastWeatherCheck && (
            <div style={{ background: '#2a2a2a', padding: '1rem', borderRadius: '4px', marginBottom: '1rem', fontSize: '0.875rem' }}>
              <p>
                <strong>Is Raining:</strong> {lastWeatherCheck.isRaining ? '🌧️ YES' : '☀️ NO'}
              </p>
              <p style={{ marginTop: '0.5rem', opacity: 0.7 }}>
                {lastWeatherCheck.timestamp}
              </p>
            </div>
          )}

          <button
            onClick={handleCheckWeather}
            style={{
              width: '100%',
              padding: '0.75rem',
              background: '#9333ea',
              color: '#fff',
              border: 'none',
              borderRadius: '4px',
              cursor: 'pointer',
              fontSize: '1rem',
              fontWeight: 'bold',
            }}
          >
            🌦️ Check Weather
          </button>
        </div>

        {/* Default Check */}
        <div style={{ background: '#1a1a1a', border: '1px solid #333', borderRadius: '8px', padding: '1.5rem' }}>
          <h2 style={{ fontSize: '1.25rem', marginBottom: '1rem' }}>🔴 Default Status</h2>

          {defaultCheckResult && (
            <div style={{ background: '#2a2a2a', padding: '1rem', borderRadius: '4px', marginBottom: '1rem', fontSize: '0.875rem' }}>
              <p>
                <strong>Default:</strong>{' '}
                <span style={{ color: defaultCheckResult.isDefault ? '#ef4444' : '#22c55e', fontWeight: 'bold' }}>
                  {defaultCheckResult.isDefault ? '🔴 TRUE' : '✅ FALSE'}
                </span>
              </p>
            </div>
          )}

          <button
            onClick={handleCheckDefault}
            style={{
              width: '100%',
              padding: '0.75rem',
              background: '#ea580c',
              color: '#fff',
              border: 'none',
              borderRadius: '4px',
              cursor: 'pointer',
              fontSize: '1rem',
              fontWeight: 'bold',
            }}
          >
            🔍 Check Default Status
          </button>
        </div>

        {/* Declare Default */}
        <div style={{ background: '#1a1a1a', border: '1px solid #333', borderRadius: '8px', padding: '1.5rem' }}>
          <h2 style={{ fontSize: '1.25rem', marginBottom: '1rem' }}>⚡ Declare Default</h2>

          <div style={{ background: '#7f1d1d', padding: '1rem', borderRadius: '4px', marginBottom: '1rem', fontSize: '0.875rem' }}>
            <p style={{ fontWeight: 'bold', marginBottom: '0.5rem' }}>Prerequisites:</p>
            <ul style={{ margin: 0, paddingLeft: '1.5rem' }}>
              <li>Host NOT paid for 15+ days</li>
              <li>Weather shows NO rain</li>
              <li>Default status = TRUE</li>
            </ul>
          </div>

          <div style={{
            background: '#2a2a2a',
            padding: '1rem',
            borderRadius: '4px',
            marginBottom: '1rem',
            fontWeight: 'bold',
            color: isDefault === true ? '#ef4444' : '#22c55e',
          }}>
            {getStatus()}
          </div>

          <button
            disabled={isDefault !== true}
            style={{
              width: '100%',
              padding: '0.75rem',
              background: isDefault === true ? '#dc2626' : '#666',
              color: '#fff',
              border: 'none',
              borderRadius: '4px',
              cursor: isDefault === true ? 'pointer' : 'not-allowed',
              fontSize: '1rem',
              fontWeight: 'bold',
            }}
          >
            ⚡ Declare Default
          </button>
        </div>
      </div>

      {/* Instructions */}
      <div style={{ background: '#1a3a3a', border: '1px solid #1e5a5a', borderRadius: '8px', padding: '1.5rem' }}>
        <h2 style={{ fontSize: '1.25rem', marginBottom: '1rem' }}>📋 Test Flow</h2>
        <ol style={{ margin: 0, paddingLeft: '1.5rem', lineHeight: '1.8' }}>
          <li>Set Project ID (usually 1)</li>
          <li>Click "Skip 15+ Days"</li>
          <li>Click "Check Weather"</li>
          <li>Click "Check Default Status"</li>
          <li>If showing 🔴 TRUE, click "Declare Default"</li>
        </ol>
      </div>
    </div>
  );
}
