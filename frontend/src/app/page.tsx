import Link from 'next/link';

export default function HomePage() {
  return (
    <div className="bg-[#0a0e1a]">
      {/* Hero */}
      <section className="relative overflow-hidden px-4 pt-20 pb-24 sm:px-6 lg:px-8">
        {/* Background glow */}
        <div className="absolute inset-0 overflow-hidden pointer-events-none">
          <div className="absolute -top-40 -right-32 w-[600px] h-[600px] bg-green-500/5 rounded-full blur-3xl" />
          <div className="absolute top-1/2 -left-64 w-[500px] h-[500px] bg-emerald-500/4 rounded-full blur-3xl" />
        </div>

        <div className="relative max-w-5xl mx-auto text-center">
          <div className="inline-flex items-center gap-2 bg-green-500/10 border border-green-500/20 rounded-full px-4 py-1.5 mb-8">
            <div className="w-1.5 h-1.5 bg-green-400 rounded-full animate-pulse" />
            <span className="text-green-400 text-sm font-medium">Running on Local Testnet</span>
          </div>

          <h1 className="text-5xl sm:text-7xl font-bold tracking-tight text-white mb-6 leading-tight">
            Decentralized
            <span className="block text-transparent bg-clip-text bg-gradient-to-r from-green-400 to-emerald-300">
              Solar Financing
            </span>
          </h1>

          <p className="text-xl text-slate-400 max-w-2xl mx-auto mb-10 leading-relaxed">
            Fund residential solar installations through fractional NFTs. Earn dual yield —
            fixed monthly repayments plus variable grid export revenue — secured on-chain.
          </p>

          <div className="flex flex-col sm:flex-row gap-4 justify-center">
            <Link
              href="/explore"
              className="bg-green-600 hover:bg-green-500 text-white font-semibold px-8 py-4 rounded-xl transition-colors text-lg"
            >
              Explore Projects
            </Link>
            <Link
              href="/host"
              className="bg-slate-800 hover:bg-slate-700 border border-slate-700 text-white font-semibold px-8 py-4 rounded-xl transition-colors text-lg"
            >
              Host a Project
            </Link>
          </div>
        </div>
      </section>

      {/* Protocol Stats */}
      <section className="px-4 sm:px-6 lg:px-8 py-12">
        <div className="max-w-5xl mx-auto">
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            {[
              { label: 'Total Value Locked', value: '$—', sub: 'USDC' },
              { label: 'Active Projects', value: '—', sub: 'Loans' },
              { label: 'Avg. Annual Yield', value: '8–14%', sub: 'Projected' },
              { label: 'Revenue Split', value: '93%', sub: 'To Investors' },
            ].map((stat) => (
              <div
                key={stat.label}
                className="bg-slate-800/50 border border-slate-700/50 rounded-2xl p-5 text-center"
              >
                <p className="text-2xl font-bold text-white">{stat.value}</p>
                <p className="text-green-400 text-xs font-medium mt-0.5">{stat.sub}</p>
                <p className="text-slate-500 text-xs mt-1">{stat.label}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* How It Works */}
      <section className="px-4 sm:px-6 lg:px-8 py-16">
        <div className="max-w-5xl mx-auto">
          <h2 className="text-3xl font-bold text-white text-center mb-3">How It Works</h2>
          <p className="text-slate-400 text-center mb-12 max-w-xl mx-auto">
            A fully on-chain protocol securing solar loans through automated revenue splitting
            and reputation-based accountability.
          </p>

          <div className="grid md:grid-cols-3 gap-6">
            {[
              {
                step: '01',
                title: 'Host Creates Project',
                desc: 'A homeowner initializes a solar project, setting the funding target, loan term, and number of fractional shares to issue.',
                color: 'from-green-500 to-emerald-400',
              },
              {
                step: '02',
                title: 'Investors Fund via NFTs',
                desc: 'Investors purchase ERC-1155 fractional shares with USDC. Once fully funded, the loan activates automatically.',
                color: 'from-emerald-500 to-teal-400',
              },
              {
                step: '03',
                title: 'Earn Dual Yield',
                desc: 'Monthly host payments + grid export revenue flow through a 93/5/2 waterfall. Pull-based dividends are always claimable.',
                color: 'from-teal-500 to-cyan-400',
              },
            ].map((item) => (
              <div
                key={item.step}
                className="bg-slate-800/50 border border-slate-700/50 rounded-2xl p-6"
              >
                <div
                  className={`inline-flex w-10 h-10 items-center justify-center rounded-xl bg-gradient-to-br ${item.color} text-white font-bold text-sm mb-4`}
                >
                  {item.step}
                </div>
                <h3 className="text-white font-semibold text-lg mb-2">{item.title}</h3>
                <p className="text-slate-400 text-sm leading-relaxed">{item.desc}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Revenue Waterfall */}
      <section className="px-4 sm:px-6 lg:px-8 py-16">
        <div className="max-w-5xl mx-auto">
          <div className="bg-slate-800/50 border border-slate-700/50 rounded-2xl p-8">
            <h2 className="text-2xl font-bold text-white mb-2">Revenue Waterfall</h2>
            <p className="text-slate-400 text-sm mb-8">
              Every dollar of revenue — host payments and grid exports — is automatically split:
            </p>

            <div className="grid md:grid-cols-3 gap-4">
              {[
                { pct: '93%', label: 'Investor Dividends', color: 'bg-green-500', desc: 'Distributed pro-rata to fractional shareholders' },
                { pct: '5%', label: 'Maintenance Reserve', color: 'bg-yellow-500', desc: 'Locked treasury for system upkeep' },
                { pct: '2%', label: 'Insurance Pool', color: 'bg-blue-500', desc: 'Default protection fund' },
              ].map((item) => (
                <div key={item.label} className="bg-slate-900/60 rounded-xl p-4">
                  <div className={`w-10 h-10 ${item.color} rounded-lg flex items-center justify-center mb-3`}>
                    <span className="text-white font-bold text-sm">{item.pct}</span>
                  </div>
                  <p className="text-white font-semibold mb-1">{item.label}</p>
                  <p className="text-slate-500 text-xs">{item.desc}</p>
                </div>
              ))}
            </div>

            {/* Bar visualization */}
            <div className="mt-6 h-3 rounded-full overflow-hidden flex">
              <div className="bg-green-500 h-full" style={{ width: '93%' }} />
              <div className="bg-yellow-500 h-full" style={{ width: '5%' }} />
              <div className="bg-blue-500 h-full" style={{ width: '2%' }} />
            </div>
          </div>
        </div>
      </section>

      {/* Reputation & Security */}
      <section className="px-4 sm:px-6 lg:px-8 py-16">
        <div className="max-w-5xl mx-auto">
          <div className="grid md:grid-cols-2 gap-6">
            <div className="bg-slate-800/50 border border-slate-700/50 rounded-2xl p-6">
              <div className="w-10 h-10 bg-purple-500/20 border border-purple-500/30 rounded-xl flex items-center justify-center mb-4">
                <svg className="w-5 h-5 text-purple-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
                </svg>
              </div>
              <h3 className="text-white font-semibold text-lg mb-2">Soulbound Reputation</h3>
              <p className="text-slate-400 text-sm leading-relaxed">
                Hosts mint a non-transferable ERC-721 reputation token. Payment defaults slash
                the score by 200 points — creating real on-chain accountability without intermediaries.
              </p>
            </div>

            <div className="bg-slate-800/50 border border-slate-700/50 rounded-2xl p-6">
              <div className="w-10 h-10 bg-orange-500/20 border border-orange-500/30 rounded-xl flex items-center justify-center mb-4">
                <svg className="w-5 h-5 text-orange-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6" />
                </svg>
              </div>
              <h3 className="text-white font-semibold text-lg mb-2">Algorithmic Buyout</h3>
              <p className="text-slate-400 text-sm leading-relaxed">
                Buyout prices are computed from a linear amortization curve. At month 60 of 120,
                it{"'"}s a 50/50 split. Investors always get a fair exit based on remaining loan principal.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* CTA */}
      <section className="px-4 sm:px-6 lg:px-8 py-20 text-center">
        <div className="max-w-2xl mx-auto">
          <h2 className="text-3xl font-bold text-white mb-4">Ready to start?</h2>
          <p className="text-slate-400 mb-8">
            Connect your wallet, get test USDC, and start investing in solar projects on the local testnet.
          </p>
          <Link
            href="/explore"
            className="bg-green-600 hover:bg-green-500 text-white font-semibold px-10 py-4 rounded-xl transition-colors text-lg inline-block"
          >
            Browse Projects
          </Link>
        </div>
      </section>
    </div>
  );
}
