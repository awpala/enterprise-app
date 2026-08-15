/** Standard inline error notice. */
export function ErrorNotice({ message }: { readonly message: string }) {
  return (
    <div className="rounded-[9px] border border-danger/30 bg-danger/10 px-[14px] py-3 text-danger" role="alert">
      {message}
    </div>
  );
}
