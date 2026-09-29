import pytest
from utils import dependencies

def test_dependency_check_reports_missing_without_installing(monkeypatch):
    monkeypatch.setattr(dependencies.importlib.util,'find_spec',lambda name: None if name=='requests' else object())
    monkeypatch.setattr(dependencies.shutil,'which',lambda _name: None)
    missing=dependencies.find_missing_dependencies(); assert 'requests' in missing and 'ffmpeg (system binary)' in missing
    with pytest.raises(dependencies.RuntimeDependencyError): dependencies.ensure_runtime_dependencies()
