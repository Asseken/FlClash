package com.follow.clash.core

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class CoreUpdaterTest {
    @get:Rule
    val folder = TemporaryFolder()

    private fun writeCore(vararg names: String) {
        for (name in names) {
            File(folder.root, name).writeText("core")
        }
    }

    @Test
    fun `reports nothing without a downloaded core`() {
        assertNull(CoreUpdater.findVersionedCore(folder.root))
    }

    @Test
    fun `picks the numerically newest core`() {
        writeCore("libclashn010928.so", "libclashn011930.so", "libclashn011928.so")

        assertEquals("libclashn011930.so", CoreUpdater.findVersionedCore(folder.root))
    }

    @Test
    fun `treats a missing version segment as zero`() {
        writeCore("libclashn011930.so", "libclashn0120.so")

        assertEquals("libclashn0120.so", CoreUpdater.findVersionedCore(folder.root))
    }

    @Test
    fun `ignores files the loader would not accept`() {
        writeCore("libclash.so", "libclashn011930.so.bak", "libclashnfoo.so", "notes.txt")

        assertNull(CoreUpdater.findVersionedCore(folder.root))
    }
}
