export function Loading({ label = 'Loading' }: { readonly label?: string }) {
  return <div className="loading"><div className="spinner" /><span>{label}</span></div>;
}

export function ErrorNotice({ message }: { readonly message: string }) {
  return <div className="notice error" role="alert">{message}</div>;
}
