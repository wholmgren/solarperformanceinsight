import datetime as dt
import logging
from typing import Set, IO, Callable, List, Tuple


from fastapi import HTTPException
import pandas as pd
from pandas.errors import EmptyDataError, ParserError  # type: ignore
from pandas.api.types import is_numeric_dtype, is_datetime64_any_dtype  # type: ignore
import pyarrow as pa  # type: ignore


from . import models


logger = logging.getLogger(__name__)


def read_csv(content: IO) -> pd.DataFrame:
    """Read a CSV into a DataFrame"""
    kwargs = dict(
        na_values=[-999.0, -9999.0],
        keep_default_na=True,
        comment="#",
        header=0,
        skip_blank_lines=True,
    )
    # read headers first to see if a "time" column is present
    try:
        head_df = pd.read_csv(content, nrows=0, **kwargs)  # type: ignore
    except (EmptyDataError, ParserError) as err:
        raise HTTPException(status_code=400, detail=err.args[0])
    for i, header in enumerate(head_df.columns):
        try:
            float(header)
        except ValueError:
            pass
        else:
            raise HTTPException(
                status_code=400,
                detail=(
                    f"The header '{header}' can be parsed as a "
                    "float indicating a header row may be missing?"
                ),
            )
        if len(header) == 0 or header.startswith("Unnamed:"):
            raise HTTPException(status_code=400, detail=f"Empty header for column {i}")

    if "time" in head_df.columns:
        kwargs["parse_dates"] = ["time"]
    content.seek(0)
    try:
        df = pd.read_csv(content, **kwargs)  # type: ignore
    except (EmptyDataError, ParserError) as err:
        raise HTTPException(status_code=400, detail=err.args[0])
    if df.empty:
        raise HTTPException(status_code=400, detail="Empty CSV file")
    return df


def read_arrow(content: IO) -> pd.DataFrame:
    """Read a buffer in Apache Arrow File format into a DataFrame"""
    try:
        table = pa.ipc.open_file(content).read_all()
    except pa.lib.ArrowInvalid as err:
        raise HTTPException(status_code=400, detail=err.args[0])
    df = table.to_pandas(split_blocks=True)
    return df


def verify_content_type(content_type: str) -> Callable[[IO], pd.DataFrame]:
    """Checks if we can read the content_type and returns the appropriate function for
    reading"""
    csv_types = ("text/csv", "application/vnd.ms-excel")
    arrow_types = (
        "application/octet-stream",
        "application/vnd.apache.arrow.file",
    )
    # reject non csv/arrow
    if content_type not in csv_types and content_type not in arrow_types:
        raise HTTPException(
            status_code=415,
            detail=(
                "Acceptable formats are CSV (text/csv) and the Apache Arrow "
                "file format (application/vnd.apache.arrow.file)"
            ),
        )
    if content_type in csv_types:
        return read_csv
    else:
        return read_arrow


def validate_dataframe(df: pd.DataFrame, columns: List[str]) -> Set[str]:
    """Validates that the input dataframe has all given columns, that the
    'time' column has a datetime type and no microseconds, and that all
    other columns are floats"""
    expected = set(columns)
    actual = set(df.columns)
    diff = expected - actual
    if len(diff) > 0:
        raise HTTPException(
            status_code=400, detail="Data is missing column(s) " + ", ".join(diff)
        )
    if "time" in expected:
        if not is_datetime64_any_dtype(df["time"]):
            raise HTTPException(
                status_code=400,
                detail='"time" column could not be parsed as a timestamp',
            )
        # check for duplicates
        extra_times = len(df["time"]) - len(df["time"].unique())
        if extra_times != 0:
            raise HTTPException(
                status_code=400,
                detail=f'"time" column has {extra_times} duplicate entries',
            )
    bad_types = []
    for col in expected - {"time"}:
        if not is_numeric_dtype(df[col]):
            bad_types.append(col)
    if bad_types:
        raise HTTPException(
            status_code=400,
            detail="The following column(s) are not numeric: " + ", ".join(bad_types),
        )
    return actual - expected


def reindex_timeseries(
    df: pd.DataFrame, jobtimeindex: models.JobTimeindex
) -> Tuple[pd.DataFrame, List[dt.datetime], List[dt.datetime]]:
    """Conforms a dataframe to the expected time index for a job"""
    # some annoying type behaviour
    newdf: pd.DataFrame
    newdf = df.copy()
    newdf.loc[:, "time"] = newdf["time"].dt.round("1s")  # type: ignore
    newdf = newdf.set_index("time").sort_index()  # type: ignore
    if newdf.index.tzinfo is None:  # type: ignore
        newdf = newdf.tz_localize(jobtimeindex.timezone)  # type: ignore
    else:
        newdf = newdf.tz_convert(jobtimeindex.timezone)  # type: ignore
    if not newdf.index.equals(jobtimeindex._time_range):  # type: ignore
        extra = list(
            newdf.index.difference(
                jobtimeindex._time_range  # type: ignore
            ).to_pydatetime()
        )
        missing = list(
            jobtimeindex._time_range.difference(  # type: ignore
                newdf.index
            ).to_pydatetime()
        )
    else:
        extra = []
        missing = []
    newdf = newdf.reindex(jobtimeindex._time_range, copy=False)  # type: ignore
    newdf.index.name = "time"  # type: ignore
    newdf.reset_index(inplace=True)  # type: ignore
    return newdf, extra, missing


def convert_to_arrow(df: pd.DataFrame) -> pa.Table:
    """Convert a DataFrame into an Arrow Table setting a time column to
    have second precision and any other columns to use float32"""
    cols = df.columns
    # save on storage by using single floats
    schema = pa.schema((col, pa.float32()) for col in cols if col != "time")
    if "time" in cols:
        if not is_datetime64_any_dtype(df["time"]):
            raise HTTPException(
                status_code=400, detail='"time" column is not a datetime'
            )
        if not hasattr(df["time"].dtype, "tz"):  # type: ignore
            tz = None
        else:
            tz = df["time"].dtype.tz  # type: ignore

        # no need to save timestamps at ns precision
        schema = schema.insert(0, pa.field("time", pa.timestamp("s", tz=tz)))
    try:
        table = pa.Table.from_pandas(df, schema=schema)
    except pa.lib.ArrowInvalid as err:
        logger.error(err.args[0])
        raise HTTPException(status_code=400, detail=err.args[0])
    return table


def dump_arrow_bytes(table: pa.Table) -> bytes:
    """Dump an Arrow table out to bytes in the Arrow File/Feather format"""
    sink = pa.BufferOutputStream()
    writer = pa.ipc.new_file(sink, table.schema)
    writer.write(table)
    writer.close()
    return sink.getvalue().to_pybytes()
