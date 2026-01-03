import zipfile
import os

def zip_directory(folder_path, output_path):
    with zipfile.ZipFile(output_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
        for root, dirs, files in os.walk(folder_path):
            for file in files:
                file_path = os.path.join(root, file)
                # Create a relative path for the zip entry
                arcname = os.path.relpath(file_path, folder_path)
                # Ensure we use forward slashes for the archive internal path
                arcname = arcname.replace(os.sep, '/')
                zipf.write(file_path, arcname)

if __name__ == "__main__":
    ext_dir = r"d:\Dev\Flutter\LinkMate\extension\firefox"
    output_zip = r"d:\Dev\Flutter\LinkMate\extension_firefox_v1.0.0.zip"
    zip_directory(ext_dir, output_zip)
    print(f"Successfully created {output_zip}")
