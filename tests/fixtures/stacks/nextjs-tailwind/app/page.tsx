import { articles } from "./articles";

export default function Home() {
  return (
    <main className="mx-auto grid max-w-3xl gap-4 p-6">
      {articles.map((a) => (
        <article key={a.slug} className="rounded border border-slate-200 p-4">
          <h2 className="text-lg font-semibold text-brand">{a.title}</h2>
          <p>{a.excerpt}</p>
        </article>
      ))}
    </main>
  );
}
